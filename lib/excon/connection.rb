require 'excon/request'

module Excon
  class Connection
    attr_reader :attributes, :proxy

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
    def initialize(url, params = {})
      uri = URI.parse(url)
      @attributes = {
        :connect_timeout  => 60,
        :headers          => {},
        :host             => uri.host,
        :mock             => Excon.mock,
        :path             => uri.path,
        :port             => uri.port.to_s,
        :query            => uri.query,
        :read_timeout     => 60,
        :scheme           => uri.scheme,
        :write_timeout    => 60
      }.merge!(params)

      # use proxy from the environment if present
      if ENV.has_key?('http_proxy')
        @proxy = setup_proxy(ENV['http_proxy'])
      elsif params.has_key?(:proxy)
        @proxy = setup_proxy(params[:proxy])
      end

      self.retry_limit = params[:retry_limit] || DEFAULT_RETRY_LIMIT

      if @attributes[:scheme] == 'https'
        # use https_proxy if that has been specified
        if ENV.has_key?('https_proxy')
          @proxy = setup_proxy(ENV['https_proxy'])
        end
      end

      if @proxy
        @attributes[:headers]['Proxy-Connection'] ||= 'Keep-Alive'
      end

      @socket_key = '' << @attributes[:host] << ':' << @attributes[:port]
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
      req = Excon::Request.new(self, @attributes.merge(params).merge({ :retry_limit => retry_limit }))
      req.invoke(&block)
    end
    
    def invoke_stub(params)
      for stub, response in Excon.stubs
        # all specified non-headers params match and no headers were specified or all specified headers match
        if (stub.keys - [:headers]).all? {|key| stub[key] == params[key] } &&
          (!stub.has_key?(:headers) || stub[:headers].keys.all? {|key| stub[:headers][key] == params[:headers][key]})
          response_attributes = case response
          when Proc
            response.call(params)
          else
            response
          end
          if block_given? && response_attributes.has_key?(:body)
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

    attr_writer :retry_limit

    def retry_limit
      @retry_limit ||= DEFAULT_RETRY_LIMIT
    end

    def socket
      sockets[@socket_key] ||= if @attributes[:scheme] == 'https'
        Excon::SSLSocket.new(@attributes, @proxy)
      else
        Excon::Socket.new(@attributes, @proxy)
      end
    end

    private
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
