module Excon
  class Socket
    include Utils

    extend Forwardable

    attr_accessor :data

    def params
      Excon.display_warning('Excon::Socket#params is deprecated use Excon::Socket#data instead.')
      @data
    end
    def params=(new_params)
      Excon.display_warning('Excon::Socket#params= is deprecated use Excon::Socket#data= instead.')
      @data = new_params
    end

    attr_reader :remote_ip

    def_delegators(:@socket, :close,    :close)

    def initialize(data = {})
      @data = data
      @nonblock = data[:nonblock]
      @read_buffer = ''
      @eof = false

      connect
    end

    def read(max_length=nil)
      if @eof
        return max_length ? nil : ''
      elsif @nonblock
        begin
          if max_length
            until @read_buffer.length >= max_length
              @read_buffer << @socket.read_nonblock(max_length - @read_buffer.length)
            end
          else
            while true
              @read_buffer << @socket.read_nonblock(@data[:chunk_size])
            end
          end
        rescue OpenSSL::SSL::SSLError => error
          if error.message == 'read would block'
            if IO.select([@socket], nil, nil, @data[:read_timeout])
              retry
            else
              raise(Excon::Errors::Timeout.new("read timeout reached"))
            end
          else
            raise(error)
          end
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable
          if IO.select([@socket], nil, nil, @data[:read_timeout])
            retry
          else
            raise(Excon::Errors::Timeout.new("read timeout reached"))
          end
        rescue EOFError
          @eof = true
        end

        if max_length
          if @read_buffer.empty?
            nil # EOF met at beginning
          else
            @read_buffer.slice!(0, max_length)
          end
        else
          # read until EOFError, so return everything
          @read_buffer.slice!(0, @read_buffer.length)
        end
      else
        begin
          Timeout.timeout(@data[:read_timeout]) do
            @socket.read(max_length)
          end
        rescue Timeout::Error
          raise Excon::Errors::Timeout.new('read timeout reached')
        end
      end
    end

    def readline
      if @eof
        raise EOFError, 'end of file reached'
      else
        line = ''
        if @nonblock
          while char = read(1)
            line << char
            break if char == $/
          end
          raise EOFError, 'end of file reached' if line.empty?
        else
          begin
            Timeout.timeout(@data[:read_timeout]) do
              line = @socket.readline
            end
          rescue Timeout::Error
            raise Excon::Errors::Timeout.new('read timeout reached')
          end
        end
        line
      end
    end

    def write(data)
      if @nonblock
        if FORCE_ENC
          data.force_encoding('BINARY')
        end
        while true
          written = nil
          begin
            # I wish that this API accepted a start position, then we wouldn't
            # have to slice data when there is a short write.
            written = @socket.write_nonblock(data)
          rescue OpenSSL::SSL::SSLError, Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable => error
            if error.is_a?(OpenSSL::SSL::SSLError) && error.message != 'write would block'
              raise error
            else
              if IO.select(nil, [@socket], nil, @data[:write_timeout])
                retry
              else
                raise Excon::Errors::Timeout.new('write timeout reached')
              end
            end
          end

          # Fast, common case.
          break if written == data.size

          # This takes advantage of the fact that most ruby implementations
          # have Copy-On-Write strings. Thusly why requesting a subrange
          # of data, we actually don't copy data because the new string
          # simply references a subrange of the original.
          data = data[written, data.size]
        end
      else
        begin
          Timeout.timeout(@data[:write_timeout]) do
            @socket.write(data)
          end
        rescue Timeout::Error
          Excon::Errors::Timeout.new('write timeout reached')
        end
      end
    end

    private

    def connect
      @socket = nil
      exception = nil

      addrinfo = if @data[:proxy]
        family = @data[:proxy][:family] || ::Socket::Constants::AF_UNSPEC
        ::Socket.getaddrinfo(@data[:proxy][:host], @data[:proxy][:port], family, ::Socket::Constants::SOCK_STREAM)
      else
        family = @data[:family] || ::Socket::Constants::AF_UNSPEC
        ::Socket.getaddrinfo(@data[:host], @data[:port], family, ::Socket::Constants::SOCK_STREAM)
      end

      addrinfo.each do |_, port, _, ip, a_family, s_type|
        @remote_ip = ip

        # nonblocking connect
        begin
          sockaddr = ::Socket.sockaddr_in(port, ip)

          socket = ::Socket.new(a_family, s_type, 0)

          if @nonblock
            socket.connect_nonblock(sockaddr)
          else
            begin
              Timeout.timeout(@data[:connect_timeout]) do
                socket.connect(sockaddr)
              end
            rescue Timeout::Error
              raise Excon::Errors::Timeout.new('connect timeout reached')
            end
          end

          @socket = socket
          break
        rescue Errno::EINPROGRESS
          unless IO.select(nil, [socket], nil, @data[:connect_timeout])
            raise(Excon::Errors::Timeout.new("connect timeout reached"))
          end
          begin
            socket.connect_nonblock(sockaddr)

            @socket = socket
            break
          rescue Errno::EISCONN
            @socket = socket
            break
          rescue SystemCallError => exception
            socket.close rescue nil
            next
          end
        rescue SystemCallError => exception
          socket.close rescue nil if socket
          next
        end
      end

      unless @socket
        # this will be our last encountered exception
        raise exception
      end

      if @data[:tcp_nodelay]
        @socket.setsockopt(::Socket::IPPROTO_TCP,
                           ::Socket::TCP_NODELAY,
                           true)
      end
    end

  end
end
