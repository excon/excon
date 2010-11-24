module Excon
  class Connection

    # Initializes a new Connection instance
    #   @param [String] url The destination URL
    #   @param [Hash] params One or more optional params
    #   @option params [String] :host The destination host's reachable DNS name or IP, in the form of a String
    #   @option params [Fixnum] :port The port on which to connect, to the destination host
    #   @option params [Hash]   :headers The default headers to supply in a request. Only used if params[:headers] is not supplied to Connection#request
    #   @option params [String] :path Default path; appears after 'scheme://host:port/'. Only used if params[:path] is not supplied to Connection#request
    #   @option params [Hash]   :query Default query; appended to the 'scheme://host:port/path/' in the form of '?key=value'. Will only be used if params[:query] is not supplied to Connection#request
    #   @option params [String] :scheme The protocol; 'https' causes OpenSSL to be used
    #   @option params [String] :body Default text to be sent over a socket. Only used if :body absent in Connection#request params
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
    end

    def request(params, &block)
      begin
        params[:path] ||= @connection[:path]
        unless params[:path][0..0] == '/'
          params[:path].insert(0, '/')
        end

        request = params[:method].to_s.upcase << ' ' << params[:path] << '?'

        for key, values in (params[:query] || @connection[:query] || {})
          for value in [*values]
            value_string = value && ('=' << CGI.escape(value.to_s))
            request << key << value_string << '&'
          end
        end
        request.chop!
        request << " HTTP/1.1\r\n"
        params[:headers] ||= @connection[:headers]
        params[:headers]['Host'] ||= params[:host] || @connection[:host]
        params[:body] ||= @connection[:body]
        params[:headers]['Content-Length'] = case params[:body]
        when File
          params[:body].binmode
          File.size(params[:body].path)
        when String
          if params[:body].respond_to?(:force_encoding)
            params[:body].force_encoding('BINARY')
          end
          params[:body].length
        else
          0
        end
        for key, value in params[:headers]
          request << key << ': ' << value << "\r\n"
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

        response = Excon::Response.parse(socket, params, &block)
        if response.headers['Connection'] == 'close'
          reset
        end
        response
      rescue => socket_error
        reset
        raise(socket_error)
      end

      if params[:expects] && ![*params[:expects]].include?(response.status)
        reset
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

    def reset
      (old_socket = sockets.delete(socket_key)) && old_socket.close
    end

    private

    def connect
      new_socket = TCPSocket.open(@connection[:host], @connection[:port])

      if @connection[:scheme] == 'https'
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        new_socket = OpenSSL::SSL::SSLSocket.new(new_socket, @ssl_context)
        new_socket.sync_close = true
        new_socket.connect
      end

      new_socket
    end

    def closed?
      sockets[socket_key] && sockets[socket_key].closed?
    end

    def socket
      if closed?
        reset
      end
      sockets[socket_key] ||= connect
    end

    def sockets
      Thread.current[:_excon_sockets] ||= {}
    end

    def socket_key
      "#{@connection[:host]}:#{@connection[:port]}"
    end
  end
end
