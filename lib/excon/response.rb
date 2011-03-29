module Excon
  class Response
    NO_ENTITY = [204, 205, 304].freeze

    attr_accessor :body, :headers, :status

    def initialize(attrs={})
      @body    = attrs[:body]    || ''
      @headers = attrs[:headers] || {}
      @status  = attrs[:status]
    end

    def self.parse(socket, params={})
      response = new(:status => socket.readline[9, 11].to_i)
      block_given = block_given?

      until ((data = socket.readline).chop!).empty?
        key, value = data.split(': ', 2)
        response.headers[key] = value
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
            while (chunk_size = socket.readline.chop!.to_i(16)) > 0
              yield socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
            socket.read(2) # 2 == "/r/n".length
          elsif connection_close
            yield socket.read
          else
            yield_content_length = Proc.new.arity != 1
            remaining = content_length
            while remaining > 0
              chunk = socket.read([CHUNK_SIZE, remaining].min)
              if yield_content_length
                yield chunk, content_length
              else
                yield chunk
              end
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

  end # class Response
end # module Excon
