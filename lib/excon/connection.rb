module Excon
  class Connection

    attr_reader :data

    def params
      $stderr.puts("Excon::Connection#params is deprecated use Excon::Connection#data instead (#{caller.first})")
      @data
    end
    def params=(new_params)
      $stderr.puts("Excon::Connection#params= is deprecated use Excon::Connection#data= instead (#{caller.first})")
      @data = new_params
    end

    def proxy
      $stderr.puts("Excon::Connection#proxy is deprecated use Excon::Connection#data[:proxy] instead (#{caller.first})")
      @data[:proxy]
    end
    def proxy=(new_proxy)
      $stderr.puts("Excon::Connection#proxy= is deprecated use Excon::Connection#data[:proxy]= instead (#{caller.first})")
      @data[:proxy] = new_proxy
    end

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
      @data = Excon.defaults.merge({
        :host       => uri.host,
        :host_port  => '' << uri.host << ':' << uri.port.to_s,
        :path       => uri.path,
        :port       => uri.port,
        :query      => uri.query,
        :scheme     => uri.scheme,
      }).merge!(params)
      # merge does not deep-dup, so make sure headers is not the original
      @data[:headers] = @data[:headers].dup

      if @data[:scheme] == HTTPS && (ENV.has_key?('https_proxy') || ENV.has_key?('HTTPS_PROXY'))
        @data[:proxy] = setup_proxy(ENV['https_proxy'] || ENV['HTTPS_PROXY'])
      elsif (ENV.has_key?('http_proxy') || ENV.has_key?('HTTP_PROXY'))
        @data[:proxy] = setup_proxy(ENV['http_proxy'] || ENV['HTTP_PROXY'])
      elsif @data.has_key?(:proxy)
        @data[:proxy] = setup_proxy(@data[:proxy])
      end

      if @data[:proxy]
        @data[:headers]['Proxy-Connection'] ||= 'Keep-Alive'
        # https credentials happen in handshake
        if @data[:scheme] == 'http' && (@data[:proxy][:user] || @data[:proxy][:password])
          auth = ['' << @data[:proxy][:user].to_s << ':' << @data[:proxy][:password].to_s].pack('m').delete(Excon::CR_NL)
          @data[:headers]['Proxy-Authorization'] = 'Basic ' << auth
        end
      end

      if ENV.has_key?('EXCON_DEBUG') || ENV.has_key?('EXCON_STANDARD_INSTRUMENTOR')
        @data[:instrumentor] = Excon::StandardInstrumentor
      end

      # Use Basic Auth if url contains a login
      if uri.user || uri.password
        @data[:headers]['Authorization'] ||= 'Basic ' << ['' << uri.user.to_s << ':' << uri.password.to_s].pack('m').delete(Excon::CR_NL)
      end

      @socket_key = '' << @data[:host_port]
      reset
    end

    def call(datum)
      begin
        response = if datum[:mock]
          invoke_stub(datum)
        else
          socket.data = datum
          # start with "METHOD /path"
          request = datum[:method].to_s.upcase << ' '
          if @data[:proxy]
            request << datum[:scheme] << '://' << datum[:host_port]
          end
          request << datum[:path]

          # add query to path, if there is one
          case datum[:query]
          when String
            request << '?' << datum[:query]
          when Hash
            request << '?'
            datum[:query].each do |key, values|
              if values.nil?
                request << key.to_s << '&'
              else
                [values].flatten.each do |value|
                  request << key.to_s << '=' << CGI.escape(value.to_s) << '&'
                end
              end
            end
            request.chop! # remove trailing '&'
          end

          # finish first line with "HTTP/1.1\r\n"
          request << HTTP_1_1

          if datum.has_key?(:request_block)
            datum[:headers]['Transfer-Encoding'] = 'chunked'
          elsif ! (datum[:method].to_s.casecmp('GET') == 0 && datum[:body].nil?)
            # The HTTP spec isn't clear on it, but specifically, GET requests don't usually send bodies;
            # if they don't, sending Content-Length:0 can cause issues.
            datum[:headers]['Content-Length'] = detect_content_length(datum[:body])
          end

          # add headers to request
          datum[:headers].each do |key, values|
            [values].flatten.each do |value|
              request << key.to_s << ': ' << value.to_s << CR_NL
            end
          end

          # add additional "\r\n" to indicate end of headers
          request << CR_NL

          # write out the request, sans body
          socket.write(request)

          # write out the body
          if datum.has_key?(:request_block)
            while true
              chunk = datum[:request_block].call
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
          elsif !datum[:body].nil?
            if datum[:body].is_a?(String)
              unless datum[:body].empty?
                socket.write(datum[:body])
              end
            else
              if datum[:body].respond_to?(:binmode)
                datum[:body].binmode
              end
              if datum[:body].respond_to?(:pos=)
                datum[:body].pos = 0
              end
              while chunk = datum[:body].read(datum[:chunk_size])
                socket.write(chunk)
              end
            end
          end

          # read the response
          response = Excon::Response.parse(socket, datum)

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

      if datum.has_key?(:expects) && ![*datum[:expects]].include?(response.status)
        reset
        raise(Excon::Errors.status_error(datum, response))
      else
        response
      end
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
      # @data has defaults, merge in new params to override
      datum = @data.merge(params)
      datum[:host_port]  = '' << datum[:host] << ':' << datum[:port].to_s
      datum[:headers] = @data[:headers].merge(datum[:headers] || {})
      datum[:headers]['Host'] = '' << datum[:host_port]
      datum[:retries_remaining] ||= datum[:retry_limit]

      # if path is empty or doesn't start with '/', insert one
      unless datum[:path][0, 1] == '/'
        datum[:path].insert(0, '/')
      end

      if block_given?
        $stderr.puts("Excon requests with a block are deprecated, pass :response_block instead (#{caller.first})")
        datum[:response_block] = Proc.new
      end

      if datum.has_key?(:instrumentor)
        if datum[:retries_remaining] < datum[:retry_limit]
          event_name = "#{datum[:instrumentor_name]}.retry"
        else
          event_name = "#{datum[:instrumentor_name]}.request"
        end
        response = datum[:instrumentor].instrument(event_name, datum) do
          call(datum)
        end
        datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.response", response.data)
        response
      else
        call(datum)
      end
    rescue => request_error
      if datum[:idempotent] && [Excon::Errors::Timeout, Excon::Errors::SocketError,
          Excon::Errors::HTTPStatusError].any? {|ex| request_error.kind_of? ex }
        datum[:retries_remaining] -= 1
        if datum[:retries_remaining] > 0
          request(datum, &block)
        else
          if datum.has_key?(:instrumentor)
            datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.error", :error => request_error)
          end
          raise(request_error)
        end
      else
        if datum.has_key?(:instrumentor)
          datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.error", :error => request_error)
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
      @data[:retry_limit] = new_retry_limit
    end

    def retry_limit
      $stderr.puts("Excon::Connection#retry_limit is deprecated, pass :retry_limit to the initializer (#{caller.first})")
      @data[:retry_limit] ||= DEFAULT_RETRY_LIMIT
    end

    def inspect
      vars = instance_variables.inject({}) do |accum, var|
        accum.merge!(var.to_sym => instance_variable_get(var))
      end
      if vars[:'@data'][:headers].has_key?('Authorization')
        vars[:'@data'] = vars[:'@data'].dup
        vars[:'@data'][:headers] = vars[:'@data'][:headers].dup
        vars[:'@data'][:headers]['Authorization'] = REDACTED
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

    def invoke_stub(datum)
      # convert File/Tempfile body to string before matching:
      unless datum[:body].nil? || datum[:body].is_a?(String)
       if datum[:body].respond_to?(:binmode)
         datum[:body].binmode
       end
       if datum[:body].respond_to?(:rewind)
         datum[:body].rewind
       end
       datum[:body] = datum[:body].read
      end

      datum[:captures] = {:headers => {}} # setup data to hold captures
      Excon.stubs.each do |stub, response|
        headers_match = !stub.has_key?(:headers) || stub[:headers].keys.all? do |key|
          case value = stub[:headers][key]
          when Regexp
            if match = value.match(datum[:headers][key])
              datum[:captures][:headers][key] = match.captures
            end
            match
          else
            value == datum[:headers][key]
          end
        end
        non_headers_match = (stub.keys - [:headers]).all? do |key|
          case value = stub[key]
          when Regexp
            if match = value.match(datum[key])
              datum[:captures][key] = match.captures
            end
            match
          else
            value == datum[key]
          end
        end
        if headers_match && non_headers_match
          response_params = case response
          when Proc
            response.call(datum)
          else
            response
          end

          if datum[:expects] && ![*datum[:expects]].include?(response_params[:status])
            # don't pass stuff into a block if there was an error
          elsif datum.has_key?(:response_block) && response_params.has_key?(:body)
            body = response_params.delete(:body)
            content_length = remaining = body.bytesize
            i = 0
            while i < body.length
              datum[:response_block].call(body[i, datum[:chunk_size]], [remaining - datum[:chunk_size], 0].max, content_length)
              remaining -= datum[:chunk_size]
              i += datum[:chunk_size]
            end
          end
          return Excon::Response.new(response_params)
        end
      end
      # if we reach here no stubs matched
      raise(Excon::Errors::StubNotFound.new('no stubs matched ' << datum.inspect))
    end

    def socket
      sockets[@socket_key] ||= if @data[:scheme] == HTTPS
        Excon::SSLSocket.new(@data)
      else
        Excon::Socket.new(@data)
      end
    end

    def sockets
      Thread.current[:_excon_sockets] ||= {}
    end

    def setup_proxy(proxy)
      case proxy
      when String
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
      else
        proxy
      end
    end

  end
end
