# frozen_string_literal: true

module Excon
  class SOCKS5Socket < Socket
    include SOCKS5

    def initialize(data = {})
      @socks5_proxy = data[:socks5_proxy]
      @proxy_host, @proxy_port, @proxy_user, @proxy_pass = parse_socks5_proxy(@socks5_proxy)
      super(data)
    end

    private

    # Proxy-swap pattern: temporarily set @data[:proxy] to the SOCKS5 proxy
    # so that Socket#connect routes the TCP connection there (inheriting DNS
    # resolution, nonblock, retry, keepalive, reuseaddr, remote_ip tracking).
    # After TCP is up, clear :proxy and run the SOCKS5 handshake.
    def connect
      @data[:proxy] = {
        host:     @proxy_host,
        hostname: @proxy_host,
        port:     @proxy_port.to_i
      }

      begin
        super
      ensure
        @data.delete(:proxy)
      end

      socks5_authenticate
      socks5_connect(@data[:host], @data[:port])
    end
  end
end
