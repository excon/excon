# frozen_string_literal: true

module Excon
  class SOCKS5SSLSocket < SSLSocket
    include SOCKS5

    def initialize(data = {})
      @socks5_proxy = data[:socks5_proxy]
      @proxy_host, @proxy_port, @proxy_user, @proxy_pass = parse_socks5_proxy(@socks5_proxy)
      super(data)
    end

    private

    # Proxy-swap pattern (same as SOCKS5Socket#connect).
    #
    # Call chain:
    #   SOCKS5SSLSocket#initialize -> super (SSLSocket#initialize)
    #     -> super (Socket#initialize) -> connect
    #       -> SOCKS5SSLSocket#connect (this method)
    #         -> super -> SSLSocket#connect -> Socket#connect (TCP to proxy)
    #       -> SOCKS5 handshake on raw TCP socket
    #     <- returns to SSLSocket#initialize
    #     -> @data[:proxy] is nil, so HTTP CONNECT is skipped (line 111)
    #     -> SSL wrapping on the SOCKS5-tunneled socket
    def connect
      @data[:proxy] = {
        host:     @proxy_host,
        hostname: @proxy_host,
        port:     @proxy_port.to_i
      }

      begin
        super
      ensure
        # Clear :proxy so SSLSocket#initialize skips HTTP CONNECT (line 111)
        @data.delete(:proxy)
      end

      socks5_authenticate
      socks5_connect(@data[:host], @data[:port])
    end
  end
end
