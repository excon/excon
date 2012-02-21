module Excon
  class SSLSocket < Socket

    # backwards compatability for 1.8.x SSLSocket (which lack nonblock)
    unless OpenSSL::SSL::SSLSocket.public_method_defined?(:connect_nonblock)

      undef_method :connect
      def connect
        @socket = TCPSocket.new(@params[:host], @params[:port])
      end

      undef_method :read
      def_delegators(:@socket, :read, :read)

      undef_method :write
      def_delegators(:@socket, :write, :write)

    end

    def initialize(params = {}, proxy = nil)
      super

      # create ssl context
      ssl_context = OpenSSL::SSL::SSLContext.new

      if Excon.defaults[:ssl_verify_peer]
        # turn verification on
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        if Excon.defaults[:ssl_ca_path]
          ssl_context.ca_path = Excon.defaults[:ssl_ca_path]
        elsif Excon.defaults[:ssl_ca_file]
          ssl_context.ca_file = Excon.defaults[:ssl_ca_file]
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

      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      @socket.sync_close = true

      if @proxy
        @socket << "CONNECT " << @params[:host] << ":" << @params[:port] << Excon::HTTP_1_1
        @socket << "Host: " << @params[:host] << ":" << @params[:port] << Excon::CR_NL << Excon::CR_NL

        # eat the proxy's connection response
        while line = @socket.readline.strip
          break if line.empty?
        end
      end

      # connect the new OpenSSL::SSL::SSLSocket
      @socket.connect

      # verify connection
      if Excon.defaults[:ssl_verify_peer]
        @socket.post_connection_check(@params[:host])
      end

      @socket
    end

  end
end
