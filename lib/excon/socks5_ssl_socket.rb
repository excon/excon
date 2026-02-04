# frozen_string_literal: true

module Excon
  # SOCKS5 + SSL socket for HTTPS connections through a SOCKS5 proxy
  # Establishes SOCKS5 tunnel first, then performs SSL handshake
  class SOCKS5SSLSocket < Socket
    include SOCKS5

    def initialize(data = {})
      @socks5_proxy = data[:socks5_proxy]
      @proxy_host, @proxy_port, @proxy_user, @proxy_pass = parse_socks5_proxy(@socks5_proxy)
      @port = data[:port] || 443
      super(data)

      # After raw socket is connected via SOCKS5, wrap with SSL
      wrap_with_ssl
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

      # SOCKS5 handshake (before SSL)
      socks5_authenticate
      socks5_connect(@data[:host], @data[:port])

      # Apply socket options before SSL wrap
      @socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      @socket.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true) if @data[:tcp_keepalive]

      @socket
    end

    def wrap_with_ssl
      ssl_context = OpenSSL::SSL::SSLContext.new

      # Security level (Ruby 2.5+)
      if @data[:ssl_security_level] && ssl_context.respond_to?(:security_level=)
        ssl_context.security_level = @data[:ssl_security_level]
      end

      # SSL context options
      ssl_context_options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      if defined?(OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS)
        ssl_context_options &= ~OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS
      end
      if defined?(OpenSSL::SSL::OP_NO_COMPRESSION)
        ssl_context_options |= OpenSSL::SSL::OP_NO_COMPRESSION
      end
      ssl_context.options = ssl_context_options

      # Ciphers and protocol versions
      ssl_context.ciphers = @data[:ciphers] if @data[:ciphers]
      ssl_context.ssl_version = @data[:ssl_version] if @data[:ssl_version]
      ssl_context.min_version = @data[:ssl_min_version] if @data[:ssl_min_version]
      ssl_context.max_version = @data[:ssl_max_version] if @data[:ssl_max_version]

      # Verification mode
      if @data[:ssl_verify_peer]
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        if (ca_file = @data[:ssl_ca_file] || ENV['SSL_CERT_FILE'])
          ssl_context.ca_file = ca_file
        end
        if (ca_path = @data[:ssl_ca_path] || ENV['SSL_CERT_DIR'])
          ssl_context.ca_path = ca_path
        end
        if (cert_store = @data[:ssl_cert_store])
          ssl_context.cert_store = cert_store
        end

        # Set default cert store if none provided
        if ssl_context.cert_store.nil?
          ssl_context.cert_store = OpenSSL::X509::Store.new
          ssl_context.cert_store.set_default_paths
        end

        if (verify_callback = @data[:ssl_verify_callback])
          ssl_context.verify_callback = verify_callback
        end
      else
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # Hostname verification (Ruby 2.4+)
      if ssl_context.respond_to?(:verify_hostname=)
        ssl_context.verify_hostname = @data[:ssl_verify_hostname]
      end

      # Client certificate
      if @data[:client_cert_data] && @data[:client_key_data]
        ssl_context.cert = OpenSSL::X509::Certificate.new(@data[:client_cert_data])
        ssl_context.key = OpenSSL::PKey.read(@data[:client_key_data], @data[:client_key_pass])
      elsif @data[:client_cert] && @data[:client_key]
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(@data[:client_cert]))
        ssl_context.key = OpenSSL::PKey.read(File.read(@data[:client_key]), @data[:client_key_pass])
      end

      # Wrap socket with SSL
      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      @socket.sync_close = true

      # SNI (Server Name Indication)
      if @socket.respond_to?(:hostname=)
        @socket.hostname = @data[:ssl_verify_peer_host] || @data[:host]
      end

      # SSL handshake
      if @nonblock
        ssl_connect_nonblock
      else
        @socket.connect
      end

      # Verify peer
      if @data[:ssl_verify_peer]
        @socket.post_connection_check(@data[:ssl_verify_peer_host] || @data[:host])
      end
    end

    def ssl_connect_nonblock
      @socket.connect_nonblock
    rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable
      if IO.select([@socket], nil, nil, @data[:connect_timeout])
        retry
      else
        raise Excon::Error::Timeout.new('SSL connect timeout')
      end
    rescue IO::WaitWritable
      if IO.select(nil, [@socket], nil, @data[:connect_timeout])
        retry
      else
        raise Excon::Error::Timeout.new('SSL connect timeout')
      end
    end
  end
end
