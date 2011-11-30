module Excon
  class Socket

    extend Forwardable

    attr_accessor :params

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(params = {}, proxy = nil)
      @params, @proxy = params, proxy
      @read_buffer, @write_buffer = '', ''
      @eof = false

      connect
    end

    def connect
      @socket = nil
      exception = nil

      addrinfo = if @proxy
        ::Socket.getaddrinfo(@proxy[:host], @proxy[:port].to_i, nil, ::Socket::Constants::SOCK_STREAM)
      else
        ::Socket.getaddrinfo(@params[:host], @params[:port].to_i, nil, ::Socket::Constants::SOCK_STREAM)
      end

      addrinfo.each do |_, port, _, ip, a_family, s_type|
        # nonblocking connect
        begin
          sockaddr = ::Socket.sockaddr_in(port, ip)

          socket = ::Socket.new(a_family, s_type, 0)

          socket.connect_nonblock(sockaddr)

          @socket = socket
          break
        rescue Errno::EINPROGRESS
          IO.select(nil, [socket], nil, @params[:connect_timeout])
          begin
            socket.connect_nonblock(sockaddr)

            @socket = socket
            break
          rescue Errno::EISCONN
            @socket = socket
            break
          rescue SystemCallError => exception
            socket.close
            next
          end
        rescue SystemCallError => exception
          socket.close
          next
        end
      end

      unless @socket
        # this will be our last encountered exception
        raise exception
      end
    end

    def read(max_length=nil)
      return nil if @eof

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
        @eof = true
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
