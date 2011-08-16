module Excon
  class Socket

    extend Forwardable

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :read,     :read)
    def_delegators(:@socket, :readline, :readline)

    def initialize(connection_params = {}, proxy = {})
      @connection_params, @proxy = connection_params, proxy

      @socket = if @proxy
        TCPSocket.open(@proxy[:host], @proxy[:port])
      else
        TCPSocket.open(@connection_params[:host], @connection_params[:port])
      end

      if @connection_params[:scheme] == 'https'
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

        @socket.connect
        # verify connection
        if Excon.ssl_verify_peer
          @socket.post_connection_check(@connection_params[:host])
        end
      end

      @socket
    end

    def write(data)
      @socket.write(data)
      @socket.flush
    end

  end
end