module Excon
  class Response

    attr_accessor :body, :headers, :status

    def attributes
      {
        :body     => body,
        :headers  => headers,
        :status   => status
      }
    end

    def initialize(attrs={})
      @body    = attrs[:body]    || ''
      @headers = attrs[:headers] || {}
      @status  = attrs[:status]
    end

    def self.parse(socket, params={})
      response = new(:status => socket.read(12)[9, 11].to_i)
      socket.readline # read the rest of the status line and CRLF

      until ((data = socket.readline).chop!).empty?
        key, value = data.split(/:\s*/, 2)
        response.headers[key] = ([*response.headers[key]] << value).compact.join(', ')
        if key.casecmp('Content-Length') == 0
          content_length = value.to_i
        elsif (key.casecmp('Transfer-Encoding') == 0) && (value.casecmp('chunked') == 0)
          transfer_encoding_chunked = true
        end
      end

      unless (['HEAD', 'CONNECT'].include?(params[:method].to_s.upcase)) || NO_ENTITY.include?(response.status)

        # check to see if expects was set and matched
        expected_status = !params.has_key?(:expects) || [*params[:expects]].include?(response.status)

        # if expects matched and there is a block, use it
        if expected_status && params.has_key?(:response_block)
          if transfer_encoding_chunked
            # 2 == "/r/n".length
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              params[:response_block].call(socket.read(chunk_size + 2).chop!, nil, nil)
            end
            socket.read(2)
          elsif remaining = content_length
            while remaining > 0
              params[:response_block].call(socket.read([params[:chunk_size], remaining].min), [remaining - params[:chunk_size], 0].max, content_length)
              remaining -= params[:chunk_size]
            end
          else
            while remaining = socket.read(params[:chunk_size])
              params[:response_block].call(remaining, remaining.length, content_length)
            end
          end
        else # no block or unexpected status
          if transfer_encoding_chunked
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              response.body << socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
            socket.read(2) # 2 == "/r/n".length
          elsif remaining = content_length
            while remaining > 0
              response.body << socket.read([params[:chunk_size], remaining].min)
              remaining -= params[:chunk_size]
            end
          else
            response.body << socket.read
          end
        end
      end

      response
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
