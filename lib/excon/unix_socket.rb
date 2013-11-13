module Excon
  class UnixSocket < Excon::Socket

    private

    def connect
      @socket  = ::Socket.new(::Socket::AF_UNIX, ::Socket::SOCK_STREAM, 0)
      sockaddr = ::Socket.sockaddr_un(@data[:socket])

      if @nonblock
        begin
          @socket.connect_nonblock(sockaddr)
        rescue Errno::EINPROGRESS
          unless IO.select(nil, [@socket], nil, @data[:connect_timeout])
            raise(Excon::Errors::Timeout.new("connect timeout reached"))
          end
          begin
            @socket.connect_nonblock(sockaddr)
          rescue Errno::EISCONN
          end
        end
      else
        begin
          Timeout.timeout(@data[:connect_timeout]) do
            @socket.connect(sockaddr)
          end
        rescue Timeout::Error
          raise Excon::Errors::Timeout.new('connect timeout reached')
        end
      end

    rescue => error
      @socket.close rescue nil if @socket
      raise error
    end

  end
end
