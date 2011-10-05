module Excon
  class Socket

    extend Forwardable

    attr_accessor :params

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(params = {}, proxy = {})
      @params, @proxy = params, proxy
      @read_buffer, @write_buffer = '', ''

      @sockaddr = if @proxy
        ::Socket.sockaddr_in(@proxy[:port].to_i, @proxy[:host])
      else
        ::Socket.sockaddr_in(@params[:port].to_i, @params[:host])
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
        IO.select(nil, [@socket], nil, @params[:connect_timeout])
        begin
          @socket.connect_nonblock(@sockaddr)
        rescue Errno::EISCONN
        end
      end
    end

    def read(max_length=nil)
      begin
        if max_length
          until @read_buffer.length >= max_length
            @read_buffer << @socket.read_nonblock(max_length - @read_buffer.length)
          end
        else
          while true
            @read_buffer << @socket.read_nonblock(CHUNK_SIZE)
          end
        end
      rescue OpenSSL::SSL::SSLError => error
        if error.message == 'read would block'
          if IO.select([@socket], nil, nil, @params[:read_timeout])
            retry
          else
            raise(Excon::Errors::Timeout.new("read timeout reached"))
          end
        end
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable
        if IO.select([@socket], nil, nil, @params[:read_timeout])
          retry
        else
          raise(Excon::Errors::Timeout.new("read timeout reached"))
        end
      rescue EOFError
      end
      if max_length
        @read_buffer.slice!(0, max_length)
      else
        # read until EOFError, so return everything
        @read_buffer.slice!(0, @read_buffer.length)
      end
    end

    def write(data)
      @write_buffer << data
      until @write_buffer.empty?
        begin
          max_length = [@write_buffer.length, Excon::CHUNK_SIZE].min
          written = @socket.write_nonblock(@write_buffer.slice(0, max_length))
          @write_buffer.slice!(0, written)
        rescue OpenSSL::SSL::SSLError => error
          if error.message == 'write would block'
            if IO.select(nil, [@socket], nil, @params[:write_timeout])
              retry
            else
              raise(Excon::Errors::Timeout.new("write timeout reached"))
            end
          end
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable
          if IO.select(nil, [@socket], nil, @params[:write_timeout])
            retry
          else
            raise(Excon::Errors::Timeout.new("write timeout reached"))
          end
        end
      end
    end

  end
end
