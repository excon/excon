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

    def_delegators(:@socket, :close)

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
          if @read_buffer.empty?
            # if we didn't read anything, try again...
            if IO.select([@socket], nil, nil, @data[:read_timeout])
              retry
            else
              raise(Excon::Errors::Timeout.new("read timeout reached"))
            end
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
      begin
        Timeout.timeout(@data[:read_timeout]) do
          @socket.readline
        end
      rescue Timeout::Error
        raise Excon::Errors::Timeout.new('read timeout reached')
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
          raise(Excon::Errors::Timeout.new('write timeout reached'))
        end
      end
    end

    def local_address
      unpacked_sockaddr[1]
    end

    def local_port
      unpacked_sockaddr[0]
    end

    private

    # IPv6 addresses need to be unwrapped for socket connections:
    #   host: "[::1]" => "::1"
    # Borrowed from ruby URI's:
    #   https://github.com/ruby/ruby/blob/deba55eb1a950b72788aa4cab10ccc032c1d37a7/lib/uri/generic.rb#L650
    def unwrapped_host_for_socket(v)
      /\A\[(.*)\]\z/ =~ v ? $1 : v
    end

    def connect
      @socket = nil
      exception = nil

      if @data[:proxy]
        family = @data[:proxy][:family] || ::Socket::Constants::AF_UNSPEC

        host = unwrapped_host_for_socket(@data[:proxy][:host])
        args = [host, @data[:proxy][:port], family, ::Socket::Constants::SOCK_STREAM]
      else
        family = @data[:family] || ::Socket::Constants::AF_UNSPEC
        host = unwrapped_host_for_socket(@data[:host])
        args = [host, @data[:port], family, ::Socket::Constants::SOCK_STREAM]
      end
      if RUBY_VERSION >= '1.9.2' && defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
        args << nil << nil << false # no reverse lookup
      end
      addrinfo = ::Socket.getaddrinfo(*args)

      addrinfo.each do |_, port, _, ip, a_family, s_type|
        @remote_ip = ip

        # nonblocking connect
        begin
          sockaddr = ::Socket.sockaddr_in(port, ip)

          socket = ::Socket.new(a_family, s_type, 0)

          if @data[:reuseaddr]
            socket.setsockopt(::Socket::Constants::SOL_SOCKET, ::Socket::Constants::SO_REUSEADDR, true)
            if defined?(::Socket::Constants::SO_REUSEPORT)
              socket.setsockopt(::Socket::Constants::SOL_SOCKET, ::Socket::Constants::SO_REUSEPORT, true)
            end
          end

          begin
            Timeout.timeout(@data[:connect_timeout]) do
              if @nonblock
                socket.connect_nonblock(sockaddr)
              else
                socket.connect(sockaddr)
              end
            end
          rescue Timeout::Error
            raise Excon::Errors::Timeout.new('connect timeout reached')
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

    def unpacked_sockaddr
      @unpacked_sockaddr ||= ::Socket.unpack_sockaddr_in(@socket.to_io.getsockname)
    rescue ArgumentError => e
      unless e.message == 'not an AF_INET/AF_INET6 sockaddr'
        raise
      end
    end

  end
end
