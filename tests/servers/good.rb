#!/usr/bin/env ruby

require 'eventmachine'
require 'stringio'
require 'uri'

module GoodServer
  # This method will be called with each request received.
  #
  #     request = {
  #       :method   => method,
  #       :uri      => URI.parse(uri),
  #       :headers  => {},
  #       :body     => ''
  #     }
  #
  # Each connection to this server is persistent unless the client sends
  # "Connection: close" in the request. If a response requires the connection
  # to be closed, it should set `@persistent = false` and send "Connection: close".
  def send_response(request)
    type, path = request[:uri].path.split('/', 3)[1, 2]
    case type
    when 'chunked'
      case path
      when 'simple'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data "Transfer-Encoding: chunked\r\n"
        send_data "\r\n"
        # chunk-extension is currently ignored.
        # this works because "6; chunk-extension".to_i => "6"
        send_data "6; chunk-extension\r\n"
        send_data "hello \r\n"
        send_data "5; chunk-extension\r\n"
        send_data "world\r\n"
        send_data "0; chunk-extension\r\n" # last-chunk
        send_data "\r\n"
      end

    when 'content-length'
      case path
      when 'simple'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data "Content-Length: 11\r\n"
        send_data "\r\n"
        send_data "hello world"
      end

    when 'unknown'
      @persistent = false
      case path
      when 'simple'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data "Connection: close\r\n"
        send_data "\r\n"
        send_data "hello world"

      when 'header_continuation'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data "Connection: close\r\n"
        send_data "Test-Header: one, two\r\n"
        send_data "Test-Header: three, four,\r\n"
        send_data "  five, six\r\n"
        send_data "\r\n"
        send_data "hello world"
      end

    when 'bad'
      # Excon will close these connections due to the errors.
      case path
      when 'malformed_header'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data "Bad-Header\r\n"  # no ':'
        send_data "\r\n"
        send_data "hello world"

      when 'malformed_header_continuation'
        send_data "HTTP/1.1 200 OK\r\n"
        send_data " Bad-Header: one, two\r\n"  # no previous header
        send_data "\r\n"
        send_data "hello world"
      end
    end

    close_connection(true) unless @persistent
  end

  def post_init
    @buffer = StringIO.new
    @buffer.set_encoding('BINARY') if @buffer.respond_to?(:set_encoding)
  end

  # Receives a String of +data+ sent from the client.
  # +data+ may only be a portion of what the client sent.
  # The data is buffered, then processed and removed from the buffer
  # as data becomes available until the @request is complete.
  def receive_data(data)
    @buffer.write(data)

    parse_headers unless @request
    parse_body if @request

    if @request_complete
      send_response(@request)
      sync_buffer
      @request = nil
      @request_complete = false
    end

    @buffer.seek(0, IO::SEEK_END)  # wait for more data
  end

  # Removes the processed portion of the buffer
  # by replacing the buffer with it's contents from the current pos.
  def sync_buffer
    @buffer.string = @buffer.read
  end

  def parse_headers
    @buffer.rewind
    # wait until buffer contains the end of the headers
    if /\sHTTP\/\d+\.\d+\r\n.*?\r\n\r\n/m =~ @buffer.read
      @buffer.rewind
      # For persistent connections, the buffer could start with the
      # \r\n chunked-message terminator from the previous request.
      # This will discard anything up to the request-line.
      until m = /^(\w+)\s(.*)\sHTTP\/\d+\.\d+$/.match(@buffer.readline.chop!); end
      method, uri = m[1, 2]

      headers = {}
      last_key = nil
      until (line = @buffer.readline.chop!).empty?
        if !line.lstrip!.nil?
          headers[last_key] << ' ' << line.rstrip
        else
          key, value = line.split(':', 2)
          headers[key] = ([headers[key]] << value.strip).compact.join(', ')
          last_key = key
        end
      end

      sync_buffer

      @chunked = headers['Transfer-Encoding'] =~ /chunked/i
      @content_length = headers['Content-Length'].to_i
      @persistent = headers['Connection'] !~ /close/i
      @request = {
        :method   => method,
        :uri      => URI.parse(uri),
        :headers  => headers,
        :body     => ''
      }
    end
  end

  def parse_body
    if @chunked
      @buffer.rewind
      until @request_complete || @buffer.eof?
        unless @chunk_size
          # in case buffer only contains a portion of the chunk-size line
          if (line = @buffer.readline) =~ /\r\n\z/
            @chunk_size = line.to_i(16)
            if @chunk_size > 0
              sync_buffer
            else # last-chunk
              @buffer.read(2)  # the final \r\n may or may not be in the buffer
              @chunk_size = nil
              @body_pos = nil
              @request_complete = true
            end
          end
        end
        if @chunk_size
          if @buffer.size >= @chunk_size + 2
            @request[:body] << @buffer.read(@chunk_size + 2).chop!
            @chunk_size = nil
            sync_buffer
          else
            break # wait for more data
          end
        end
      end
    elsif @content_length > 0
      @buffer.rewind
      unless @buffer.eof?  # buffer only contained the headers
        @request[:body] << @buffer.read(@content_length - @request[:body].size)
        if @request[:body].size == @content_length
          @request_complete = true
        else
          sync_buffer
        end
      end
    else
      # no body
      @request_complete = true
    end
  end

  def chunks_for(str)
    chunks = ''
    str.force_encoding('BINARY') if str.respond_to?(:force_encoding)
    chunk_size = str.size / 2
    until (chunk = str.slice!(0, chunk_size)).empty?
      chunks << chunk.size.to_s(16) << "\r\n"
      chunks << chunk << "\r\n"
    end
    chunks << "0\r\n" # last-chunk
  end

  # only supports a single quality parameter for tokens
  def parse_encodings(encodings)
    return [] if encodings.nil?
    split_header_value(encodings).map do |value|
      token, q_val = /^(.*?)(?:;q=(.*))?$/.match(value.strip)[1, 2]
      if q_val && q_val.to_f == 0
        nil
      else
        [token, (q_val || 1).to_f]
      end
    end.compact.sort_by {|_, q_val| q_val }.map {|token, _| token }
  end

  # Splits a header value +str+ according to HTTP specification.
  def split_header_value(str)
    return [] if str.nil?
    str.strip.scan(%r'\G((?:"(?:\\.|[^"])+?"|[^",]+)+)
                        (?:,\s*|\Z)'xn).flatten
  end
end

EM.run do
  EM.start_server("127.0.0.1", 9292, GoodServer)
  $stderr.puts "ready"
end
