module Excon
  class UnixSocket < Excon::Socket

    private

    def connect
      @socket = nil
      exception = nil

      begin
        socket = ::UNIXSocket.new(@data[:socket])

        @socket = socket
      rescue Errno::ECONNREFUSED => exception
        socket.close if socket
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
