module Excon
  class SSLSocket < Socket

    def initialize(params = {}, proxy = nil)
      @params, @proxy = params, proxy
      check_nonblock_support

      super

      # create ssl context
      ssl_context = OpenSSL::SSL::SSLContext.new

      if params[:ssl_verify_peer]
        # turn verification on
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        if params[:ssl_ca_path]
          ssl_context.ca_path = params[:ssl_ca_path]
        elsif params[:ssl_ca_file]
          ssl_context.ca_file = params[:ssl_ca_file]
        else
          # use default cert store
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          ssl_context.cert_store = store
        end
      else
        # turn verification off
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      if @params.has_key?(:client_cert) && @params.has_key?(:client_key)
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(@params[:client_cert]))
        ssl_context.key = OpenSSL::PKey::RSA.new(File.read(@params[:client_key]))
      end

      if @proxy
        request = 'CONNECT ' << @params[:host_port] << Excon::HTTP_1_1
        request << 'Host: ' << @params[:host_port] << Excon::CR_NL

        if @proxy[:password] || @proxy[:user]
          auth = ['' << @proxy[:user].to_s << ':' << @proxy[:password].to_s].pack('m').delete(Excon::CR_NL)
          request << "Proxy-Authorization: Basic " << auth << Excon::CR_NL
        end

        request << 'Proxy-Connection: Keep-Alive' << Excon::CR_NL

        request << Excon::CR_NL

        # write out the proxy setup request
        @socket.write(request)

        # eat the proxy's connection response
        Excon::Response.parse(@socket, { :expects => 200, :method => "CONNECT" })
      end

      # convert Socket to OpenSSL::SSL::SSLSocket
      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      @socket.sync_close = true
      @socket.connect

      # Server Name Indication (SNI) RFC 3546
      if @socket.respond_to?(:hostname=)
        @socket.hostname = @params[:host]
      end

      # verify connection
      if params[:ssl_verify_peer]
        @socket.post_connection_check(@params[:host])
      end

      @socket
    end

    def connect
      check_nonblock_support
      super
    end

    def read(max_length=nil)
      check_nonblock_support
      super
    end

    def write(data)
      check_nonblock_support
      super
    end

    private

    def check_nonblock_support
      # backwards compatability for things lacking nonblock
      if !DEFAULT_NONBLOCK && params[:nonblock]
        $stderr.puts("Excon nonblock is not supported by your OpenSSL::SSL::SSLSocket")
        params[:nonblock] = false
      end
    end

  end
end
