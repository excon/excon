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
      block_given = block_given?

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

        # don't pass stuff into a block if there was an error
        if params[:expects] && ![*params[:expects]].include?(response.status)
          block_given = false
        end

        if block_given
          if response.headers.has_key?('Transfer-Encoding') && response.headers['Transfer-Encoding'].casecmp('chunked') == 0
            while true
              chunk_size = socket.readline.chop!.to_i(16)
              break if chunk_size < 1
              yield socket.read(chunk_size+2).chop! # 2 == "/r/n".length
            end
          elsif response.headers.has_key?('Connection') && response.headers['Connection'].casecmp('close') == 0
            yield socket.read
          elsif response.headers.has_key?('Content-Length')
            remaining = response.headers['Content-Length'].to_i
            while remaining > 0
              yield socket.read([CHUNK_SIZE, remaining].min)
              remaining -= CHUNK_SIZE
            end
          end
        else
          if response.headers.has_key?('Transfer-Encoding') && response.headers['Transfer-Encoding'].casecmp('chunked') == 0
            while true
              chunk_size = socket.readline.chop!.to_i(16)
              break if chunk_size < 1
              response.body << socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
            end
          elsif response.headers.has_key?('Connection') && response.headers['Connection'].casecmp('close') == 0
            response.body << socket.read
          elsif response.headers.has_key?('Content-Length')
            remaining = response.headers['Content-Length'].to_i
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
