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
          connection.write(request)

          if params[:body]
            if params[:body].is_a?(String)
              connection.write(params[:body])
            else
              while chunk = params[:body].read(CHUNK_SIZE)
                connection.write(chunk)
              end
            end
          end

          response = Excon::Response.new
          response.status = connection.readline[9..11].to_i
          while true
            data = connection.readline.chop!
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
                block.call(connection.read([CHUNK_SIZE, remaining].min))
                remaining -= CHUNK_SIZE
              end
            elsif response.headers['Transfer-Encoding'] == 'chunked'
              while true
                chunk_size = connection.readline.chop!.to_i(16)
                chunk = connection.read(chunk_size + 2).chop! # 2 == "/r/n".length
                if chunk_size > 0
                  block.call(chunk)
                else
                  break
                end
              end
            elsif response.headers['Connection'] == 'close'
              block.call(connection.read)
              Thread.current[:_excon_connection] = nil
            end
          end
        rescue => connection_error
          Thread.current[:_excon_connection] = nil
          raise(connection_error)
        end

        if params[:expects] && ![*params[:expects]].include?(response.status)
          Thread.current[:_excon_connection] = nil
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

      def connection
        if !Thread.current[:_excon_connection] || Thread.current[:_excon_connection].closed?
          Thread.current[:_excon_connection] = establish_connection
        end
        Thread.current[:_excon_connection]
      end

      def establish_connection
        connection = TCPSocket.open(@uri.host, @uri.port)

        if @uri.scheme == 'https'
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
          connection = OpenSSL::SSL::SSLSocket.new(connection, @ssl_context)
          connection.sync_close = true
          connection.connect
        end

        connection
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
