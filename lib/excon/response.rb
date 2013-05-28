module Excon
  class Response

    attr_accessor :data

    # backwards compatability reader/writers
    def body=(new_body)
      @data[:body] = new_body
    end
    def body
      @data[:body]
    end
    def headers=(new_headers)
      @data[:headers] = new_headers
    end
    def headers
      @data[:headers]
    end
    def status=(new_status)
      @data[:status] = new_status
    end
    def status
      @data[:status]
    end
    def remote_ip=(new_remote_ip)
      @data[:remote_ip] = new_remote_ip
    end
    def remote_ip
      @data[:remote_ip]
    end

    def self.parse(socket, datum)
      datum[:response] = {
        :body       => '',
        :headers    => {},
        :status     => socket.read(12)[9, 11].to_i,
        :remote_ip  => socket.respond_to?(:remote_ip) && socket.remote_ip
      }
      socket.readline # read the rest of the status line and CRLF

      until ((data = socket.readline).chop!).empty?
        key, value = data.split(/:\s*/, 2)
        datum[:response][:headers][key] = ([*datum[:response][:headers][key]] << value).compact.join(', ')
        if key.casecmp('Content-Length') == 0
          content_length = value.to_i
        elsif (key.casecmp('Transfer-Encoding') == 0) && (value.casecmp('chunked') == 0)
          transfer_encoding_chunked = true
        end
      end

      unless (['HEAD', 'CONNECT'].include?(datum[:method].to_s.upcase)) || NO_ENTITY.include?(datum[:response][:status])

        # check to see if expects was set and matched
        expected_status = !datum.has_key?(:expects) || [*datum[:expects]].include?(datum[:response][:status])

        # if expects matched and there is a block, use it
        if expected_status && datum.has_key?(:response_block)
          if transfer_encoding_chunked
            # 2 == "/r/n".length
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              datum[:response_block].call(socket.read(chunk_size + 2).chop!, nil, nil)
            end
            socket.read(2)
          elsif remaining = content_length
            while remaining > 0
              datum[:response_block].call(socket.read([datum[:chunk_size], remaining].min), [remaining - datum[:chunk_size], 0].max, content_length)
              remaining -= datum[:chunk_size]
            end
          else
            while remaining = socket.read(datum[:chunk_size])
              datum[:response_block].call(remaining, remaining.length, content_length)
            end
          end
        else # no block or unexpected status
          if transfer_encoding_chunked
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              datum[:response][:body] << socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
            socket.read(2) # 2 == "/r/n".length
          elsif remaining = content_length
            while remaining > 0
              datum[:response][:body] << socket.read([datum[:chunk_size], remaining].min)
              remaining -= datum[:chunk_size]
            end
          else
            datum[:response][:body] << socket.read
          end
        end
      end
      datum
    end

    def initialize(params={})
      @data = {
        :body     => '',
        :headers  => {}
      }.merge(params)
      @body      = @data[:body]
      @headers   = @data[:headers]
      @status    = @data[:status]
      @remote_ip = @data[:remote_ip]
    end

    def [](key)
      @data[key]
    end

    def params
      Excon.display_warning("Excon::Response#params is deprecated use Excon::Response#data instead (#{caller.first})")
      data
    end

    # Retrieve a specific header value. Header names are treated case-insensitively.
    #   @param [String] name Header name
    def get_header(name)
      headers.each do |key,value|
        if key.casecmp(name) == 0
          return value
        end
      end
      nil
    end

  end # class Response
end # module Excon
