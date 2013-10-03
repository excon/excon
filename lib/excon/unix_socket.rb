module Excon
  class UnixSocket < Excon::Socket

    private

    def connect
      begin
        @socket = ::UNIXSocket.new(@data[:socket])
      rescue Errno::ECONNREFUSED
        @socket.close if @socket
        raise
      end

      if @data[:tcp_nodelay]
        @socket.setsockopt(::Socket::IPPROTO_TCP,
                           ::Socket::TCP_NODELAY,
                           true)
      end
    end

  end
end
