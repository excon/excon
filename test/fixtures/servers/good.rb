require 'stringio'
require 'uri'
require 'zlib'

class GoodServer
  def initialize(socket)
    @socket = socket
  end

  # Serves requests from the socket until the client goes away or either
  # side asks for the connection to be closed.
  def run
    while (request = read_request)
      @response = +''
      send_response(request)
      @socket.write(@response)
      break unless @persistent
    end
  end

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
  # to be closed, use `start_response(:persistent => false)`.
  def send_response(request)
    type, path = request[:uri].path.split('/', 3)[1, 2]
    case type
    when 'echo'
      case path
      when 'request'
        data = Marshal.dump(request)
        start_response
        write "Content-Length: #{ data.size }\r\n"
        write "\r\n"
        write data

      when 'request_count'
        (@request_count ||= '0').next!
        start_response
        write "Content-Length: #{ @request_count.size }\r\n"
        write "Connection: Keep-Alive\r\n"
        write "\r\n"
        write @request_count

      when /(content|transfer)-encoded\/?(.*)/
        if (encoding_type = $1) == 'content'
          accept_header = 'Accept-Encoding'
          encoding_header = 'Content-Encoding'
        else
          accept_header = 'TE'
          encoding_header = 'Transfer-Encoding'
        end
        chunked = $2 == 'chunked'

        encodings = parse_encodings(request[:headers][accept_header])
        while encoding = encodings.pop
          break if ['gzip', 'deflate', 'deflate-raw'].include?(encoding)
        end

        case encoding
        when 'gzip'
          body = request[:body]
          if(body.nil? || body.empty?)
            body = ''
          else
            io = (Zlib::GzipWriter.new(StringIO.new) << request[:body]).finish
            io.rewind
            body = io.read
          end
        when 'deflate'
          deflator = Zlib::Deflate.new(nil)
          body = deflator.deflate(request[:body], Zlib::FINISH)
          deflator.close
        when 'deflate-raw'
          # drops the zlib header
          deflator = Zlib::Deflate.new(nil, -Zlib::MAX_WBITS)
          body = deflator.deflate(request[:body], Zlib::FINISH)
          deflator.close
          encoding = 'deflate' # treat as deflate other than dropping header
        else
          body = request[:body]
        end

        # simulate server pre/post content encoding
        encodings = [
          request[:headers]["#{ encoding_header }-Pre"],
          encoding,
          request[:headers]["#{ encoding_header }-Post"],
        ]
        if chunked && encoding_type == 'transfer'
          encodings << 'chunked'
        end
        encodings = encodings.compact.join(', ')

        start_response
        # let the test know what the server sent
        write "#{ encoding_header }-Sent: #{ encodings }\r\n"
        write "#{ encoding_header }: #{ encodings }\r\n" unless encodings.empty?
        if chunked
          if encoding_type == 'content'
            write "Transfer-Encoding: chunked\r\n"
          end
          write "\r\n"
          write chunks_for(body)
          write "\r\n"
        else
          write "Content-Length: #{ body.bytesize }\r\n"
          write "\r\n"
          write body
        end
      end

    when 'chunked'
      case path
      when 'simple'
        start_response
        write "Transfer-Encoding: chunked\r\n"
        write "\r\n"
        # chunk-extension is currently ignored.
        # this works because "6; chunk-extension".to_i => "6"
        write "6; chunk-extension\r\n"
        write "hello \r\n"
        write "5; chunk-extension\r\n"
        write "world\r\n"
        write "0; chunk-extension\r\n" # last-chunk
        write "\r\n"

      # merged trailers also support continuations
      when 'trailers'
        start_response
        write "Transfer-Encoding: chunked\r\n"
        write "Test-Header: one, two\r\n"
        write "\r\n"
        write chunks_for('hello world')
        write "Test-Header: three, four,\r\n"
        write "\tfive, six\r\n"
        write "\r\n"
      end

    when 'content-length'
      case path
      when 'simple'
        start_response
        write "Content-Length: 11\r\n"
        write "\r\n"
        write "hello world"
      end

    when 'unknown'
      case path
      when 'cookies'
        start_response(:persistent => false)
        write "Set-Cookie: one, two\r\n"
        write "Set-Cookie: three, four\r\n"
        write "\r\n"
        write "hello world"

      when 'simple'
        start_response(:persistent => false)
        write "\r\n"
        write "hello world"

      when 'header_continuation'
        start_response(:persistent => false)
        write "Test-Header: one, two\r\n"
        write "Test-Header: three, four,\r\n"
        write "  five, six\r\n"
        write "\r\n"
        write "hello world"
      end

    when 'bad'
      # Excon will close these connections due to the errors.
      case path
      when 'malformed_header'
        start_response
        write "Bad-Header\r\n"  # no ':'
        write "\r\n"
        write "hello world"

      when 'malformed_header_continuation'
        write "HTTP/1.1 200 OK\r\n"
        write " Bad-Header: one, two\r\n"  # no previous header
        write "\r\n"
        write "hello world"
      end

    when 'not-found'
      start_response(:status => "404 Not Found")
      write "Content-Length: 11\r\n"
      write "\r\n"
      write "hello world"
    end
  end

  # Sends response status-line, plus headers common to all responses.
  def start_response(opts = {})
    opts = {
      :status     => '200 OK',
      :persistent => @persistent  # true unless client sent Connection: close
    }.merge!(opts)

    @persistent = opts[:persistent]
    write "HTTP/1.1 #{ opts[:status] }\r\n"
    write "Connection: close\r\n" unless @persistent
  end

  # Buffers +data+ to be written once the response is complete.
  def write(data)
    @response << data
  end

  # Reads the next request from the socket, returning nil once the client has
  # closed the connection.
  def read_request
    # skip any blank lines preceding the request-line
    until (line = @socket.gets("\r\n")) != "\r\n"; end
    return if line.nil?

    method, uri = /^(\w+)\s(.*)\sHTTP\/\d+\.\d+$/.match(line.chomp)[1, 2]

    headers = {}
    last_key = nil
    until (line = @socket.readline("\r\n").chomp).empty?
      if !line.lstrip!.nil?
        headers[last_key] << ' ' << line.rstrip
      else
        key, value = line.split(':', 2)
        headers[key] = ([headers[key]] << value.strip).compact.join(', ')
        last_key = key
      end
    end

    @persistent = headers['Connection'] !~ /close/i

    body = if headers['Transfer-Encoding'] =~ /chunked/i
      read_chunked_body
    else
      @socket.read(headers['Content-Length'].to_i)
    end

    {
      :method   => method,
      :uri      => URI.parse(uri),
      :headers  => headers,
      :body     => body
    }
  end

  def read_chunked_body
    body = +''
    until (chunk_size = @socket.readline("\r\n").to_i(16)).zero?
      body << @socket.read(chunk_size)
      @socket.read(2) # \r\n
    end
    # discard trailers, up to and including the final \r\n
    until @socket.readline("\r\n") == "\r\n"; end
    body
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
