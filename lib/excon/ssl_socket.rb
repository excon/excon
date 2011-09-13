module Excon
  class SSLSocket < Socket

    # backwards compatability for 1.8.x SSLSocket (which lack nonblock)
    unless OpenSSL::SSL::SSLSocket.public_method_defined?(:connect_nonblock)

      undef_method :connect
      def connect
        @socket.connect(@sockaddr)
      end

      undef_method :read
      def_delegators(:@socket, :read, :read)

      undef_method :write
      def_delegators(:@socket, :write, :write)

    end

    def initialize(connection_params = {}, proxy = {})
      super

      # create ssl context
      ssl_context = OpenSSL::SSL::SSLContext.new

      if Excon.ssl_verify_peer
        # turn verification on
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        if Excon.ssl_ca_path
          ssl_context.ca_path = Excon.ssl_ca_path
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

      if @connection_params.has_key?(:client_cert) && @connection_params.has_key?(:client_key)
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(@connection_params[:client_cert]))
        ssl_context.key = OpenSSL::PKey::RSA.new(File.read(@connection_params[:client_key]))
      end

      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      @socket.sync_close = true

      if @proxy
        @socket << "CONNECT " << @connection_params[:host] << ":" << @connection_params[:port] << HTTP_1_1
        @socket << "Host: " << @connection_params[:host] << ":" << @connection_params[:port] << CR_NL << CR_NL

        # eat the proxy's connection response
        while line = @socket.readline.strip
          break if line.empty?
        end
      end

      # connect the new OpenSSL::SSL::SSLSocket
      @socket.connect

      # verify connection
      if Excon.ssl_verify_peer
        @socket.post_connection_check(@connection_params[:host])
      end

      @socket
    end

  end
end