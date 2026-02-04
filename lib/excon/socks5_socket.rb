# frozen_string_literal: true

module Excon
  # SOCKS5 socket for HTTP connections through a SOCKS5 proxy
  class SOCKS5Socket < Socket
    include SOCKS5

    def initialize(data = {})
      @socks5_proxy = data[:socks5_proxy]
      @proxy_host, @proxy_port, @proxy_user, @proxy_pass = parse_socks5_proxy(@socks5_proxy)
      super(data)
    end

    private

    def connect
      @socket = nil

      # Resolve and connect to SOCKS5 proxy
      begin
        proxy_info = ::Addrinfo.tcp(@proxy_host, @proxy_port.to_i)
      rescue => e
        raise Excon::Error::Socket.new(e)
      end

      @socket = ::Socket.new(proxy_info.afamily, ::Socket::SOCK_STREAM, 0)
      connect_to_proxy(proxy_info)

      # SOCKS5 handshake
      socks5_authenticate
      socks5_connect(@data[:host], @data[:port])

      # Apply socket options
      @socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      @socket.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true) if @data[:tcp_keepalive]

      @socket
    end
  end
end
