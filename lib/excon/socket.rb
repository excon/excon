module Excon
  class Socket

    extend Forwardable

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(connection_params = {}, proxy = {})
      @connection_params, @proxy = connection_params, proxy
      @read_buffer, @write_buffer = '', ''

      @read_would_block_exceptions = [
        Errno::EAGAIN, Errno::EWOULDBLOCK,
        # used by 1.9 and openssl-nonblock
        defined?(IO::WaitReadable) ? IO::WaitReadable : nil
      ].compact

      @write_would_block_exceptions = [
        Errno::EAGAIN, Errno::EWOULDBLOCK,
        # used by 1.9 and openssl-nonblock
        defined?(IO::WaitWritable) ? IO::WaitWritable : nil
      ].compact

      @sockaddr = if @proxy
        ::Socket.sockaddr_in(@proxy[:port], @proxy[:host])
      else
        ::Socket.sockaddr_in(@connection_params[:port], @connection_params[:host])
      end

      @socket = ::Socket.new(::Socket::Constants::AF_INET, ::Socket::Constants::SOCK_STREAM, 0)

      connect

      @socket
    end

    def connect
      # nonblocking connect
      begin
        @socket.connect_nonblock(@sockaddr)
      rescue Errno::EINPROGRESS
        IO.select(nil, [@socket], nil, @connection_params[:connect_timeout])
        begin
          @socket.connect_nonblock(@sockaddr)
        rescue Errno::EISCONN
        end
      end
    end

    def read(max_length)
      begin
        until @read_buffer.length >= max_length
          @read_buffer << @socket.read_nonblock(max_length)
        end
      rescue *@read_would_block_exceptions
        if IO.select([@socket], nil, nil, @connection_params[:read_timeout])
          retry
        else
          raise(Timeout::Error)
        end
      end
      @read_buffer.slice!(0, max_length)
    end

    def write(data)
      @write_buffer << data
      until @write_buffer.empty?
        begin
          max_length = [@write_buffer.length, Excon::CHUNK_SIZE].min
          @socket.write_nonblock(@write_buffer.slice!(0, max_length))
        rescue *@write_would_block_exceptions
          if IO.select(nil [@socket], nil, @connection_params[:write_timeout])
            retry
          else
            raise(Timeout::Error)
          end
        end
      end
    end

  end
end
