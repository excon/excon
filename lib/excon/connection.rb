unless Excon.mocking?

  module Excon
    class Connection

      def initialize(url)
        @uri = URI.parse(url)
      end

      def request(params)
        begin
          params[:path] ||= ''
          unless params[:path][0..0] == '/'
            params[:path] = "/#{params[:path]}"
          end
          if params[:query] && !params[:query].empty?
            params[:path] << "?#{params[:query]}"
          end
          request = "#{params[:method]} #{params[:path]} HTTP/1.1\r\n"
          params[:headers] ||= {}
          params[:headers]['Host'] = params[:host] || @uri.host
          if params[:body] && !params[:headers]['Content-Length']
            params[:headers]['Content-Length'] = params[:body].length
          end
          for key, value in params[:headers]
            request << "#{key}: #{value}\r\n"
          end
          request << "\r\n"
          socket.write(request)

          if params[:body]
            if params[:body].is_a?(String)
              socket.write(params[:body])
            else
              while chunk = params[:body].read(CHUNK_SIZE)
                socket.write(chunk)
              end
            end
          end

          response = Excon::Response.new
          response.status = socket.readline[9..11].to_i
          while true
            data = socket.readline.chop!
            unless data.empty?
              key, value = data.split(': ')
              response.headers[key] = value
            else
              break
            end
          end

          unless params[:method] == 'HEAD'
            block = if !params[:block] || (params[:expects] && ![*params[:expects]].include?(response.status))
              response.body = ''
              lambda { |chunk| response.body << chunk }
            else
              params[:block]
            end

            if response.headers['Content-Length']
              remaining = response.headers['Content-Length'].to_i
              while remaining > 0
                block.call(socket.read([CHUNK_SIZE, remaining].min))
                remaining -= CHUNK_SIZE
              end
            elsif response.headers['Transfer-Encoding'] == 'chunked'
              while true
                chunk_size = socket.readline.chop!.to_i(16)
                chunk = socket.read(chunk_size + 2).chop! # 2 == "/r/n".length
                if chunk_size > 0
                  block.call(chunk)
                else
                  break
                end
              end
            elsif response.headers['Connection'] == 'close'
              block.call(socket.read)
              reset_socket
            end
          end
        rescue => socket_error
          reset_socket
          raise(socket_error)
        end

        if params[:expects] && ![*params[:expects]].include?(response.status)
          reset_socket
          raise(Excon::Errors.status_error(params, response))
        else
          response
        end

      rescue => request_error
        if params[:idempotent] &&
            (!request_error.is_a?(Excon::Errors::Error) || response.status != 404)
          retries_remaining ||= 4
          retries_remaining -= 1
          if retries_remaining > 0
            retry
          end
        else
          raise(request_error)
        end
      end

      private

      def reset_socket
        new_socket = TCPSocket.open(@uri.host, @uri.port)

        if @uri.scheme == 'https'
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
          new_socket = OpenSSL::SSL::SSLSocket.new(new_socket, @ssl_context)
          new_socket.sync_close = true
          new_socket.connect
        end

        Thread.current[:_excon_sockets][@uri.to_s] = new_socket
      end

      def socket
        Thread.current[:_excon_sockets] ||= {}
        if !Thread.current[:_excon_sockets][@uri.to_s] || Thread.current[:_excon_sockets][@uri.to_s].closed?
          reset_socket
        end
        Thread.current[:_excon_sockets][@uri.to_s]
      end

    end
  end

else

  module Excon
    class Connection

      def initialize(url)
      end

      def request(params)
        for key in Excon.mocks.keys
          if key == params
            response = Excon.mocks[key]
            break
          end
        end
        unless response
          response = Excon::Response.new
          response.status = 404
          response.headers = { 'Content-Length' => 0 }
        end

        if params[:expects] && ![*params[:expects]].include?(response.status)
          raise(Excon::Errors.status_error(params[:expects], response.status, response))
        else
          response
        end

      rescue => request_error
        if params[:idempotent]
          retries_remaining ||= 3
          retries_remaining -= 1
          if retries_remaining > 0
            retry
          end
        else
          raise(request_error)
        end
      end

    end
  end

end
