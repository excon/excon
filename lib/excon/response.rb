module Excon
  class Response
    attr_accessor :body, :headers, :status

    def initialize(attrs={})
      @body    = attrs[:body]    || ''
      @headers = attrs[:headers] || {}
      @status  = attrs[:status]
    end

    def self.parse(socket, params={})
      response = new(:status => socket.readline[9, 11].to_i)

      while true
        (data = socket.readline).chop!

        unless data.empty?
          key, value = data.split(': ')
          response.headers[key] = value
        else
          break
        end
      end

      unless params[:method].to_s.casecmp('HEAD') == 0

        if response.headers.has_key?('Transfer-Encoding') && response.headers['Transfer-Encoding'].casecmp('chunked') == 0
          while true
            chunk_size = socket.readline.chop!.to_i(16)

            break if chunk_size < 1
                                          # 2 == "/r/n".length
            (chunk = socket.read(chunk_size+2)).chop!

            if block_given?
              yield chunk
            else
              response.body << chunk
            end
          end

        elsif response.headers.has_key?('Connection') && response.headers['Connection'].casecmp('close') == 0
          chunk = socket.read

          if block_given?
            yield chunk
          else
            response.body << chunk
          end

        elsif response.headers.has_key?('Content-Length')
          remaining = response.headers['Content-Length'].to_i

          while remaining > 0
            chunk = socket.read([CHUNK_SIZE, remaining].min)

            if block_given?
              yield chunk
            else
              response.body << chunk
            end

            remaining -= CHUNK_SIZE
          end
        end
      end

      return response
    end

  end # class Response
end # module Excon
