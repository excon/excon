module Excon
  class Socket

    extend Forwardable

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :read,     :read)
    def_delegators(:@socket, :readline, :readline)

    def initialize(connection_params = {}, proxy = {})
      @connection_params, @proxy = connection_params, proxy
      @socket = connect
    end

    def connect
      new_socket = open_socket

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

        new_socket = open_ssl_socket(new_socket, ssl_context)
      end

      new_socket
    end

    def open_ssl_socket(socket, ssl_context)
      new_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      new_socket.sync_close = true

      if @proxy
        new_socket << "CONNECT " << @connection_params[:host] << ":" << @connection_params[:port] << HTTP_1_1
        new_socket << "Host: " << @connection_params[:host] << ":" << @connection_params[:port] << CR_NL << CR_NL

        # eat the proxy's connection response
        while line = new_socket.readline.strip
          break if line.empty?
        end
      end

      new_socket.connect
      # verify connection
      if Excon.ssl_verify_peer
        new_socket.post_connection_check(@connection_params[:host])
      end
      new_socket
    end

    def open_socket
      if @proxy
        socket = TCPSocket.open(@proxy[:host], @proxy[:port])
      else
        socket = TCPSocket.open(@connection_params[:host], @connection_params[:port])
      end
      socket
    end

    def write(data)
      @socket.write(data)
      @socket.flush
    end

  end
end