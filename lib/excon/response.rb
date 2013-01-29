module Excon
  class Response

    attr_accessor :body, :headers, :status, :remote_ip

    def data
      {
        :body      => body,
        :headers   => headers,
        :status    => status,
        :remote_ip => remote_ip
      }
    end

    def params
      $stderr.puts("Excon::Response#params is deprecated use Excon::Response#data instead (#{caller.first})")
      data
    end

    def initialize(params={})
      @body      = params[:body]    || ''
      @headers   = params[:headers] || {}
      @status    = params[:status]
      @remote_ip = params[:remote_ip]
    end

    def self.parse(socket, datum={})
      response_datum = {
        :body       => '',
        :headers    => {},
        :status     => socket.read(12)[9, 11].to_i,
        :remote_ip  => socket.remote_ip
      }
      socket.readline # read the rest of the status line and CRLF

      until ((data = socket.readline).chop!).empty?
        key, value = data.split(/:\s*/, 2)
        response_datum[:headers][key] = ([*response_datum[:headers][key]] << value).compact.join(', ')
        if key.casecmp('Content-Length') == 0
          content_length = value.to_i
        elsif (key.casecmp('Transfer-Encoding') == 0) && (value.casecmp('chunked') == 0)
          transfer_encoding_chunked = true
        end
      end

      unless (['HEAD', 'CONNECT'].include?(datum[:method].to_s.upcase)) || NO_ENTITY.include?(response_datum[:status])

        # check to see if expects was set and matched
        expected_status = !datum.has_key?(:expects) || [*datum[:expects]].include?(response_datum[:status])

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
              response_datum[:body] << socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
            socket.read(2) # 2 == "/r/n".length
          elsif remaining = content_length
            while remaining > 0
              response_datum[:body] << socket.read([datum[:chunk_size], remaining].min)
              remaining -= datum[:chunk_size]
            end
          else
            response_datum[:body] << socket.read
          end
        end
      end

      response_datum
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
