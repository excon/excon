module Excon
  class Response
    NO_ENTITY = [204, 205, 304].freeze

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
      response = new(:status => socket.readline[9, 11].to_i)
      block_given = block_given?

      until ((data = socket.readline).chop!).empty?
        key, value = data.split(/:\s*/, 2)
        response.headers[key] = ([*response.headers[key]] << value).compact.join(', ')
        if key.casecmp('Content-Length') == 0
          content_length = value.to_i
        elsif (key.casecmp('Transfer-Encoding') == 0) && (value.casecmp('chunked') == 0)
          transfer_encoding_chunked = true
        elsif (key.casecmp('Connection') == 0) && (value.casecmp('close') == 0)
          connection_close = true
        end
      end

      unless (params[:method].to_s.casecmp('HEAD') == 0) || NO_ENTITY.include?(response.status)

        # don't pass stuff into a block if there was an error
        if params[:expects] && ![*params[:expects]].include?(response.status)
          block_given = false
        end

        if block_given
          if transfer_encoding_chunked
            # 2 == "/r/n".length
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              yield(socket.read(chunk_size + 2).chop!, nil, content_length)
            end
            socket.read(2)
          elsif connection_close
            remaining = socket.read
            yield(remaining, remaining.length, content_length)
          else
            remaining = content_length
            while remaining > 0
              yield(socket.read([CHUNK_SIZE, remaining].min), [remaining - CHUNK_SIZE, 0].max, content_length)
              remaining -= CHUNK_SIZE
            end
          end
        else
          if transfer_encoding_chunked
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              response.body << socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
            socket.read(2) # 2 == "/r/n".length
          elsif connection_close
            response.body << socket.read
          else
            remaining = content_length
            while remaining > 0
              response.body << socket.read([CHUNK_SIZE, remaining].min)
              remaining -= CHUNK_SIZE
            end
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
