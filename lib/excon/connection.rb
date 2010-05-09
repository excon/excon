module Excon
  class Connection

    def initialize(url, params = {})
      uri = URI.parse(url)
      @connection = {
        :headers  => {},
        :host     => uri.host,
        :path     => uri.path,
        :port     => uri.port,
        :query    => uri.query,
        :scheme   => uri.scheme
      }.merge!(params)
      reset_socket
    end

    def request(params, &block)
      begin
        params[:path] ||= @connection[:path]
        unless params[:path][0..0] == '/'
          params[:path] = "/#{params[:path]}"
        end
        request = "#{params[:method]} #{params[:path]}"
        if (params[:query] && !params[:query].empty?) || @connection[:query]
          request << "?#{params[:query]}"
        end
        request << " HTTP/1.1\r\n"
        params[:headers] ||= @connection[:headers]
        params[:headers]['Host'] ||= params[:host] || @connection[:host]
        unless params[:headers]['Content-Length']
          params[:headers]['Content-Length'] = (params[:body] && params[:body].length) || 0
        end
        for key, value in params[:headers]
          request << "#{key}: #{value}\r\n"
        end
        request << "\r\n"
        socket.write(request)

        if params[:body] ||= @connection[:body]
          if params[:body].is_a?(String)
            socket.write(params[:body])
          else
            while chunk = params[:body].read(CHUNK_SIZE)
              socket.write(chunk)
            end
          end
        end

        response = Excon::Response.parse(socket, params, &block)
        if response.headers['Connection'] == 'close'
          reset_socket
        end
        response
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
        else
          raise(request_error)
        end
      else
        raise(request_error)
      end
    end

    private

    def reset_socket
      new_socket = TCPSocket.open(@connection[:host], @connection[:port])

      if @connection[:scheme] == 'https'
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        new_socket = OpenSSL::SSL::SSLSocket.new(new_socket, @ssl_context)
        new_socket.sync_close = true
        new_socket.connect
      end

      Thread.current[:_excon_sockets] ||= {}
      Thread.current[:_excon_sockets][@connection.inspect] = new_socket
    end

    def socket
      Thread.current[:_excon_sockets] ||= {}
      if !Thread.current[:_excon_sockets][@connection.inspect] || Thread.current[:_excon_sockets][@connection.inspect].closed?
        reset_socket
      end
      Thread.current[:_excon_sockets][@connection.inspect]
    end

  end
end
