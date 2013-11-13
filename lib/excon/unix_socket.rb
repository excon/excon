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
    end

  end
end
