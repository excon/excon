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
      @connection = Excon.defaults.merge({
        :host       => uri.host,
        :host_port  => '' << uri.host << ':' << uri.port.to_s,
        :path       => uri.path,
        :port       => uri.port.to_s,
        :query      => uri.query,
        :scheme     => uri.scheme,
      }).merge!(params)
      # merge does not deep-dup, so make sure headers is not the original
      @connection[:headers] = @connection[:headers].dup

      @proxy = nil

      if @connection[:scheme] == HTTPS && (ENV.has_key?('https_proxy') || ENV.has_key?('HTTPS_PROXY'))
        @proxy = setup_proxy(ENV['https_proxy'] || ENV['HTTPS_PROXY'])
      elsif (ENV.has_key?('http_proxy') || ENV.has_key?('HTTP_PROXY'))
        @proxy = setup_proxy(ENV['http_proxy'] || ENV['HTTP_PROXY'])
      elsif @connection.has_key?(:proxy)
        @proxy = setup_proxy(@connection[:proxy])
      end

      if @proxy
        @connection[:headers]['Proxy-Connection'] ||= 'Keep-Alive'
        # https credentials happen in handshake
        if @connection[:scheme] == 'http' && (@proxy[:user] || @proxy[:password])
          auth = ['' << @proxy[:user].to_s << ':' << @proxy[:password].to_s].pack('m').delete(Excon::CR_NL)
          @connection[:headers]['Proxy-Authorization'] = 'Basic ' << auth
        end
      end

      if ENV.has_key?('EXCON_DEBUG') || ENV.has_key?('EXCON_STANDARD_INSTRUMENTOR')
        @connection[:instrumentor] = Excon::StandardInstrumentor
      end

      # Use Basic Auth if url contains a login
      if uri.user || uri.password
        @connection[:headers]['Authorization'] ||= 'Basic ' << ['' << uri.user.to_s << ':' << uri.password.to_s].pack('m').delete(Excon::CR_NL)
      end

      @socket_key = '' << @connection[:host_port]
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
      params[:host_port]  = '' << params[:host] << ':' << params[:port].to_s
      params[:headers] = @connection[:headers].merge(params[:headers] || {})
      params[:headers]['Host'] ||= '' << params[:host_port]

      # if path is empty or doesn't start with '/', insert one
      unless params[:path][0, 1] == '/'
        params[:path].insert(0, '/')
      end

      if block_given?
        $stderr.puts("Excon requests with a block are deprecated, pass :response_block instead (#{caller.first})")
        params[:response_block] = Proc.new
      end

      if params.has_key?(:instrumentor)
        if (retries_remaining ||= params[:retry_limit]) < params[:retry_limit]
          event_name = "#{params[:instrumentor_name]}.retry"
        else
          event_name = "#{params[:instrumentor_name]}.request"
        end
        response = params[:instrumentor].instrument(event_name, params) do
          request_kernel(params)
        end
        params[:instrumentor].instrument("#{params[:instrumentor_name]}.response", response.attributes)
        response
      else
        request_kernel(params)
      end
    rescue => request_error
      if params[:idempotent] && [Excon::Errors::Timeout, Excon::Errors::SocketError,
          Excon::Errors::HTTPStatusError].any? {|ex| request_error.kind_of? ex }
        retries_remaining ||= params[:retry_limit]
        retries_remaining -= 1
        if retries_remaining > 0
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
      class_eval <<-DEF, __FILE__, __LINE__ + 1
        def #{method}(params={}, &block)
          request(params.merge!(:method => :#{method}), &block)
        end
      DEF
    end

    def retry_limit=(new_retry_limit)
      $stderr.puts("Excon::Connection#retry_limit= is deprecated, pass :retry_limit to the initializer (#{caller.first})")
      @connection[:retry_limit] = new_retry_limit
    end

    def retry_limit
      $stderr.puts("Excon::Connection#retry_limit is deprecated, pass :retry_limit to the initializer (#{caller.first})")
      @connection[:retry_limit] ||= DEFAULT_RETRY_LIMIT
    end

    def inspect
      vars = instance_variables.inject({}) do |accum, var|
        accum.merge!(var.to_sym => instance_variable_get(var))
      end
      if vars[:'@connection'][:headers].has_key?('Authorization')
        vars[:'@connection'] = vars[:'@connection'].dup
        vars[:'@connection'][:headers] = vars[:'@connection'][:headers].dup
        vars[:'@connection'][:headers]['Authorization'] = REDACTED
      end
      inspection = '#<Excon::Connection:'
      inspection << (object_id << 1).to_s(16)
      vars.each do |key, value|
        inspection << ' ' << key.to_s << '=' << value.inspect
      end
      inspection << '>'
      inspection
    end

    private

    def detect_content_length(body)
      if body.is_a?(String)
        if FORCE_ENC
          body.force_encoding('BINARY')
        end
        body.length
      elsif body.respond_to?(:size)
        # IO object: File, Tempfile, etc.
        body.size
      else
        begin
          File.size(body) # for 1.8.7 where file does not have size
        rescue
          0
        end
      end
    end

    def request_kernel(params)
      begin
        response = if params[:mock]
          invoke_stub(params)
        else
          socket.params = params
          # start with "METHOD /path"
          request = params[:method].to_s.upcase << ' '
          if @proxy
            request << params[:scheme] << '://' << params[:host_port]
          end
          request << params[:path]

          # add query to path, if there is one
          case params[:query]
          when String
            request << '?' << params[:query]
          when Hash
            request << '?'
            params[:query].each do |key, values|
              if values.nil?
                request << key.to_s << '&'
              else
                [*values].each do |value|
                  request << key.to_s << '=' << CGI.escape(value.to_s) << '&'
                end
              end
            end
            request.chop! # remove trailing '&'
          end

          # finish first line with "HTTP/1.1\r\n"
          request << HTTP_1_1

          if params.has_key?(:request_block)
            params[:headers]['Transfer-Encoding'] = 'chunked'
          elsif ! (params[:method].to_s.casecmp('GET') == 0 && params[:body].nil?)
            # The HTTP spec isn't clear on it, but specifically, GET requests don't usually send bodies;
            # if they don't, sending Content-Length:0 can cause issues.
            params[:headers]['Content-Length'] = detect_content_length(params[:body])
          end

          # add headers to request
          params[:headers].each do |key, values|
            [*values].each do |value|
              request << key.to_s << ': ' << value.to_s << CR_NL
            end
          end

          # add additional "\r\n" to indicate end of headers
          request << CR_NL

          # write out the request, sans body
          socket.write(request)

          # write out the body
          if params.has_key?(:request_block)
            while true
              chunk = params[:request_block].call
              if FORCE_ENC
                chunk.force_encoding('BINARY')
              end
              if chunk.length > 0
                socket.write(chunk.length.to_s(16) << CR_NL << chunk << CR_NL)
              else
                socket.write('0' << CR_NL << CR_NL)
                break
              end
            end
          elsif !params[:body].nil?
            if params[:body].is_a?(String)
              unless params[:body].empty?
                socket.write(params[:body])
              end
            else
              if params[:body].respond_to?(:binmode)
                params[:body].binmode
              end
              if params[:body].respond_to?(:pos=)
                params[:body].pos = 0
              end
              while chunk = params[:body].read(params[:chunk_size])
                socket.write(chunk)
              end
            end
          end

          # read the response
          response = Excon::Response.parse(socket, params)

          if response.headers['Connection'] == 'close'
            reset
          end

          response
        end
      rescue Excon::Errors::StubNotFound, Excon::Errors::Timeout => error
        raise(error)
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

      # convert File/Tempfile body to string before matching:
      unless params[:body].nil? || params[:body].is_a?(String)
       if params[:body].respond_to?(:binmode)
         params[:body].binmode
       end
       if params[:body].respond_to?(:rewind)
         params[:body].rewind
       end
       params[:body] = params[:body].read
      end

      params[:captures] = {:headers => {}} # setup data to hold captures
      Excon.stubs.each do |stub, response|
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

          if params[:expects] && ![*params[:expects]].include?(response_attributes[:status])
            # don't pass stuff into a block if there was an error
          elsif params.has_key?(:response_block) && response_attributes.has_key?(:body)
            body = response_attributes.delete(:body)
            content_length = remaining = body.bytesize
            i = 0
            while i < body.length
              params[:response_block].call(body[i, params[:chunk_size]], [remaining - params[:chunk_size], 0].max, content_length)
              remaining -= params[:chunk_size]
              i += params[:chunk_size]
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
      {
        :host       => uri.host,
        :host_port  => '' << uri.host << ':' << uri.port.to_s,
        :password   => uri.password,
        :port       => uri.port,
        :scheme     => uri.scheme,
        :user       => uri.user
      }
    end

  end
end
