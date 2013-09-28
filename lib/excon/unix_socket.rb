module Excon
  class UnixSocket

    extend Forwardable

    attr_accessor :data

    def params
      Excon.display_warning("Excon::Socket#params is deprecated use Excon::Socket#data instead (#{caller.first})")
      @data
    end
    def params=(new_params)
      Excon.display_warning("Excon::Socket#params= is deprecated use Excon::Socket#data= instead (#{caller.first})")
      @data = new_params
    end

    attr_reader :remote_ip

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(data = {})
      @data = data
      @read_buffer = ''
      @eof = false

      connect
    end

    private

    def connect
      @socket = nil
      exception = nil

      begin
        socket = ::UNIXSocket.new(host)

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
