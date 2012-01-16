module Excon
  class Connection
    attr_reader :connection, :proxy

    # Initializes a new Connection instance
    #   @param [String] url The destination URL
    #   @param [Hash<Symbol, >] params One or more optional params
    #     @option params [String] :body Default text to be sent over a socket. Only used if :body absent in Connection#request params
    #     @option params [Hash<Symbol, String>] :headers The default headers to supply in a request. Only used if params[:headers] is not supplied to Connection#request
    #     @option params [String] :host The destination host's reachable DNS name or IP, in the form of a String
    #     @option params [String] :path Default path; appears after 'scheme://host:port/'. Only used if params[:path] is not supplied to Connection#request
    #     @option params [Fixnum] :port The port on which to connect, to the destination host
    #     @option params [Hash]   :query Default query; appended to the 'scheme://host:port/path/' in the form of '?key=value'. Will only be used if params[:query] is not supplied to Connection#request
    #     @option params [String] :scheme The protocol; 'https' causes OpenSSL to be used
    #     @option params [String] :proxy Proxy server; e.g. 'http://myproxy.com:8888'
    #     @option params [Fixnum] :retry_limit Set how many times we'll retry a failed request.  (Default 4)
    #     @option params [Class] :instrumentor Responds to #instrument as in ActiveSupport::Notifications
    #     @option params [String] :instrumentor_name Name prefix for #instrument events.  Defaults to 'excon'
    def initialize(url, params = {})
      uri = URI.parse(url)
      @connection = {
        :connect_timeout   => 60,
        :headers           => {},
        :host              => uri.host,
        :instrumentor_name => 'excon',
        :mock              => Excon.instance_variable_get(:@mock),
        :path              => uri.path,
        :port              => uri.port.to_s,
        :query             => uri.query,
        :read_timeout      => 60,
        :retry_limit       => DEFAULT_RETRY_LIMIT,
        :scheme            => uri.scheme,
        :write_timeout     => 60
      }.merge!(params)

      # use proxy from the environment if present
      if ENV.has_key?('http_proxy')
        @proxy = setup_proxy(ENV['http_proxy'])
      elsif params.has_key?(:proxy)
        @proxy = setup_proxy(params[:proxy])
      end

      if @connection[:scheme] == HTTPS
        # use https_proxy if that has been specified
        if ENV.has_key?('https_proxy')
          @proxy = setup_proxy(ENV['https_proxy'])
        end
      end

      if @proxy
        @connection[:headers]['Proxy-Connection'] ||= 'Keep-Alive'
      end

      @socket_key = '' << @connection[:host] << ':' << @connection[:port]
      reset
    end

    # Sends the supplied request to the destination host.
    #   @yield [chunk] @see Response#self.parse
    #   @param [Hash<Symbol, >] params One or more optional params, override defaults set in Connection.new
    #     @option params [String] :body text to be sent over a socket
    #     @option params [Hash<Symbol, String>] :headers The default headers to supply in a request
    #     @option params [String] :host The destination host's reachable DNS name or IP, in the form of a String
    #     @option params [String] :path appears after 'scheme://host:port/'
    #     @option params [Fixnum] :port The port on which to connect, to the destination host
    #     @option params [Hash]   :query appended to the 'scheme://host:port/path/' in the form of '?key=value'
    #     @option params [String] :scheme The protocol; 'https' causes OpenSSL to be used
    def request(params, &block)
      # connection has defaults, merge in new params to override
      params = @connection.merge(params)
      params[:headers] = @connection[:headers].merge(params[:headers] || {})
      params[:headers]['Host'] ||= '' << params[:host] << ':' << params[:port]

      # if path is empty or doesn't start with '/', insert one
      unless params[:path][0, 1] == '/'
        params[:path].insert(0, '/')
      end

      if params.has_key?(:instrumentor)
        if (retries_remaining ||= params[:retry_limit]) < params[:retry_limit]
          event_name = "#{params[:instrumentor_name]}.retry"
        else
          event_name = "#{params[:instrumentor_name]}.request"
        end
        params[:instrumentor].instrument(event_name, params) do
          request_kernel(params, &block)
        end
      else
        request_kernel(params, &block)
      end
    rescue => request_error
      if params[:idempotent] && [Excon::Errors::SocketError,
          Excon::Errors::HTTPStatusError].any? {|ex| request_error.kind_of? ex }
        retries_remaining ||= params[:retry_limit]
        retries_remaining -= 1
        if retries_remaining > 0
          if params[:body].respond_to?(:pos=)
            params[:body].pos = 0
          end
          retry
        else
          if params.has_key?(:instrumentor)
            params[:instrumentor].instrument("#{params[:instrumentor_name]}.error", :error => request_error)
          end
          raise(request_error)
        end
      else
        if params.has_key?(:instrumentor)
          params[:instrumentor].instrument("#{params[:instrumentor_name]}.error", :error => request_error)
        end
        raise(request_error)
      end
    end

    def reset
      (old_socket = sockets.delete(@socket_key)) && old_socket.close
    end

    # Generate HTTP request verb methods
    Excon::HTTP_VERBS.each do |method|
      eval <<-DEF
        def #{method}(params={}, &block)
          request(params.merge!(:method => :#{method}), &block)
        end
      DEF
    end

    def retry_limit=(new_retry_limit)
      puts("Excon::Connection#retry_limit= is deprecated, pass :retry_limit to the initializer (#{caller.first})")
      @connection[:retry_limit] = new_retry_limit
    end

    def retry_limit
      puts("Excon::Connection#retry_limit is deprecated, pass :retry_limit to the initializer (#{caller.first})")
      @connection[:retry_limit] ||= DEFAULT_RETRY_LIMIT
    end

  private

    def request_kernel(params, &block)
      begin
        response = if params[:mock]
          invoke_stub(params, &block)
        else
          socket.params = params
          # start with "METHOD /path"
          request = params[:method].to_s.upcase << ' '
          if @proxy
            request << params[:scheme] << '://' << params[:host] << ':' << params[:port]
          end
          request << params[:path]

          # add query to path, if there is one
          case params[:query]
          when String
            request << '?' << params[:query]
          when Hash
            request << '?'
            for key, values in params[:query]
              if values.nil?
                request << key.to_s << '&'
              else
                for value in [*values]
                  request << key.to_s << '=' << CGI.escape(value.to_s) << '&'
                end
              end
            end
            request.chop! # remove trailing '&'
          end

          # finish first line with "HTTP/1.1\r\n"
          request << HTTP_1_1

          # calculate content length and set to handle non-ascii
          unless params[:headers].has_key?('Content-Length')
            params[:headers]['Content-Length'] = case params[:body]
            when File
              params[:body].binmode
              File.size(params[:body])
            when String
              if FORCE_ENC
                params[:body].force_encoding('BINARY')
              end
              params[:body].length
            else
              0
            end
          end

          # add headers to request
          for key, values in params[:headers]
            for value in [*values]
              request << key.to_s << ': ' << value.to_s << CR_NL
            end
          end

          # add additional "\r\n" to indicate end of headers
          request << CR_NL

          # write out the request, sans body
          socket.write(request)

          # write out the body
          if params[:body]
            if params[:body].is_a?(String)
              socket.write(params[:body])
            else
              while chunk = params[:body].read(CHUNK_SIZE)
                socket.write(chunk)
              end
            end
          end

          # read the response
          response = Excon::Response.parse(socket, params, &block)

          if response.headers['Connection'] == 'close'
            reset
          end

          response
        end
      rescue Excon::Errors::StubNotFound => stub_not_found
        raise(stub_not_found)
      rescue => socket_error
        reset
        raise(Excon::Errors::SocketError.new(socket_error))
      end

      if params.has_key?(:expects) && ![*params[:expects]].include?(response.status)
        reset
        raise(Excon::Errors.status_error(params, response))
      else
        response
      end
    end

    def invoke_stub(params)
      block_given = block_given?
      params[:captures] = {:headers => {}} # setup data to hold captures
      for stub, response in Excon.stubs
        headers_match = !stub.has_key?(:headers) || stub[:headers].keys.all? do |key|
          case value = stub[:headers][key]
          when Regexp
            if match = value.match(params[:headers][key])
              params[:captures][:headers][key] = match.captures
            end
            match
          else
            value == params[:headers][key]
          end
        end
        non_headers_match = (stub.keys - [:headers]).all? do |key|
          case value = stub[key]
          when Regexp
            if match = value.match(params[key])
              params[:captures][key] = match.captures
            end
            match
          else
            value == params[key]
          end
        end
        if headers_match && non_headers_match
          response_attributes = case response
          when Proc
            response.call(params)
          else
            response
          end

          # don't pass stuff into a block if there was an error
          if params[:expects] && ![*params[:expects]].include?(response_attributes[:status])
            block_given = false
          end

          if block_given && response_attributes.has_key?(:body)
            body = response_attributes.delete(:body)
            content_length = remaining = body.bytesize
            i = 0
            while i < body.length
              yield(body[i, CHUNK_SIZE], [remaining - CHUNK_SIZE, 0].max, content_length)
              remaining -= CHUNK_SIZE
              i += CHUNK_SIZE
            end
          end
          return Excon::Response.new(response_attributes)
        end
      end
      # if we reach here no stubs matched
      raise(Excon::Errors::StubNotFound.new('no stubs matched ' << params.inspect))
    end

    def socket
      sockets[@socket_key] ||= if @connection[:scheme] == HTTPS
        Excon::SSLSocket.new(@connection, @proxy)
      else
        Excon::Socket.new(@connection, @proxy)
      end
    end

    def sockets
      Thread.current[:_excon_sockets] ||= {}
    end

    def setup_proxy(proxy)
      uri = URI.parse(proxy)
      unless uri.host and uri.port and uri.scheme
        raise Excon::Errors::ProxyParseError, "Proxy is invalid"
      end
      {:host => uri.host, :port => uri.port, :scheme => uri.scheme}
    end

  end
end
