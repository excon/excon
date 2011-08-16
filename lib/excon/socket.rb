module Excon
  class Socket

    extend Forwardable

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(connection_params = {}, proxy = {})
      @connection_params, @proxy = connection_params, proxy

      @socket = ::Socket.new(::Socket::Constants::AF_INET, ::Socket::Constants::SOCK_STREAM, 0)

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
      end

      # nonblocking connect
      if @proxy
        sockaddr = ::Socket.sockaddr_in(@proxy[:port], @proxy[:host])
      else
        sockaddr = ::Socket.sockaddr_in(@connection_params[:port], @connection_params[:host])
      end
      begin
        @socket.connect_nonblock(sockaddr)
      rescue Errno::EINPROGRESS
        IO.select(nil, [@socket], nil, @connection_params[:connect_timeout])
        begin
          @socket.connect_nonblock(sockaddr)
        rescue Errno::EISCONN
        end
      end

      if @connection_params[:scheme] == 'https'
        # verify connection
        if Excon.ssl_verify_peer
          @socket.post_connection_check(@connection_params[:host])
        end
      end

      @socket
    end

    def read(max_length)
      begin
        @socket.read_nonblock(max_length)
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK
        IO.select([@socket], nil, nil, @connection.params[:read_timeout])
        retry
      end
    end

    def write(data)
      remaining = data.length
      until remaining == 0
        begin
          remaining -= @socket.write_nonblock(data)
        rescue Errno::EAGAIN, IO::WaitWritable
          IO.select(nil [@socket], nil, @connection_params[:write_timeout])
          retry
        end
      end
    end

  end
end