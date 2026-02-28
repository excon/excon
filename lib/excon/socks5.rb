# frozen_string_literal: true

module Excon
  # SOCKS5 protocol implementation (RFC 1928, RFC 1929)
  # Shared module for SOCKS5Socket and SOCKS5SSLSocket
  module SOCKS5
    SOCKS5_VERSION = 0x05
    SOCKS5_RESERVED = 0x00

    # Authentication methods
    SOCKS5_NO_AUTH = 0x00
    SOCKS5_AUTH_USERNAME_PASSWORD = 0x02
    SOCKS5_NO_ACCEPTABLE_AUTH = 0xFF

    # Commands
    SOCKS5_CMD_CONNECT = 0x01

    # Address types
    SOCKS5_ATYP_IPV4 = 0x01
    SOCKS5_ATYP_DOMAIN = 0x03
    SOCKS5_ATYP_IPV6 = 0x04

    # Reply codes
    SOCKS5_SUCCESS = 0x00
    SOCKS5_ERRORS = {
      0x01 => 'General SOCKS server failure',
      0x02 => 'Connection not allowed by ruleset',
      0x03 => 'Network unreachable',
      0x04 => 'Host unreachable',
      0x05 => 'Connection refused',
      0x06 => 'TTL expired',
      0x07 => 'Command not supported',
      0x08 => 'Address type not supported'
    }.freeze

    # Maximum hostname length per RFC 1928
    MAX_HOSTNAME_LENGTH = 255

    private

    # Parse SOCKS5 proxy string into components
    # @param proxy_string [String] Proxy specification in various formats
    # @return [Array<String, String, String, String>] host, port, user, pass
    def parse_socks5_proxy(proxy_string)
      # Support formats:
      #   host:port
      #   user:pass@host:port
      #   socks5://host:port
      #   socks5://user:pass@host:port
      proxy_string = proxy_string.to_s.sub(%r{^socks5://}, '')

      user = nil
      pass = nil

      if proxy_string.include?('@')
        auth, host_port = proxy_string.split('@', 2)
        user, pass = auth.split(':', 2)
      else
        host_port = proxy_string
      end

      host, port = host_port.split(':', 2)
      port ||= '1080'

      [host, port, user, pass]
    end

    # Perform SOCKS5 authentication handshake
    def socks5_authenticate
      auth_methods = if @proxy_user && @proxy_pass
        [SOCKS5_NO_AUTH, SOCKS5_AUTH_USERNAME_PASSWORD]
      else
        [SOCKS5_NO_AUTH]
      end

      greeting = [SOCKS5_VERSION, auth_methods.length, *auth_methods].pack('C*')
      @socket.write(greeting)

      response = socks5_read_exactly(2)
      version, chosen_method = response.unpack('CC')

      if version != SOCKS5_VERSION
        raise Excon::Error::Socket.new(Exception.new("SOCKS5 proxy returned invalid version: #{version}"))
      end

      case chosen_method
      when SOCKS5_NO_AUTH
        # No authentication required
      when SOCKS5_AUTH_USERNAME_PASSWORD
        unless @proxy_user && @proxy_pass
          raise Excon::Error::Socket.new(Exception.new('SOCKS5 proxy requires authentication but no credentials provided'))
        end
        socks5_username_password_auth
      when SOCKS5_NO_ACCEPTABLE_AUTH
        raise Excon::Error::Socket.new(Exception.new('SOCKS5 proxy: no acceptable authentication methods'))
      else
        raise Excon::Error::Socket.new(Exception.new("SOCKS5 proxy: unsupported authentication method #{chosen_method}"))
      end
    end

    # RFC 1929: Username/Password Authentication
    def socks5_username_password_auth
      auth_request = [
        0x01, # auth protocol version
        @proxy_user.bytesize,
        @proxy_user,
        @proxy_pass.bytesize,
        @proxy_pass
      ].pack('CCA*CA*')

      @socket.write(auth_request)

      response = socks5_read_exactly(2)
      _, status = response.unpack('CC')

      unless status == 0x00
        raise Excon::Error::Socket.new(Exception.new('SOCKS5 proxy authentication failed'))
      end
    end

    # Request connection to target through SOCKS5 proxy
    def socks5_connect(host, port)
      if host.bytesize > MAX_HOSTNAME_LENGTH
        raise Excon::Error::Socket.new(Exception.new("SOCKS5: hostname exceeds maximum length of #{MAX_HOSTNAME_LENGTH} bytes"))
      end

      # Build CONNECT request with domain name (let proxy resolve DNS)
      request = [SOCKS5_VERSION, SOCKS5_CMD_CONNECT, SOCKS5_RESERVED].pack('CCC')
      request += [SOCKS5_ATYP_DOMAIN, host.bytesize, host].pack('CCA*')
      request += [port.to_i].pack('n')

      @socket.write(request)

      response = socks5_read_exactly(4)
      version, reply, _, atyp = response.unpack('CCCC')

      if version != SOCKS5_VERSION
        raise Excon::Error::Socket.new(Exception.new("SOCKS5 proxy returned invalid version: #{version}"))
      end

      unless reply == SOCKS5_SUCCESS
        error_msg = SOCKS5_ERRORS[reply] || "Unknown error (#{reply})"
        raise Excon::Error::Socket.new(Exception.new("SOCKS5 proxy connect failed: #{error_msg}"))
      end

      # Read and discard bound address (not needed for CONNECT)
      socks5_read_bound_address(atyp)
    end

    def socks5_read_bound_address(atyp)
      case atyp
      when SOCKS5_ATYP_IPV4
        socks5_read_exactly(4 + 2) # 4 bytes IP + 2 bytes port
      when SOCKS5_ATYP_DOMAIN
        domain_len = socks5_read_exactly(1).unpack1('C')
        socks5_read_exactly(domain_len + 2)
      when SOCKS5_ATYP_IPV6
        socks5_read_exactly(16 + 2) # 16 bytes IP + 2 bytes port
      else
        raise Excon::Error::Socket.new(Exception.new("SOCKS5 proxy returned unknown address type: #{atyp}"))
      end
    end

    # Read exact number of bytes with timeout support
    def socks5_read_exactly(nbytes)
      data = ''.dup
      deadline = @data[:read_timeout] ? Time.now + @data[:read_timeout] : nil

      while data.bytesize < nbytes
        if deadline
          remaining = deadline - Time.now
          if remaining <= 0
            raise Excon::Error::Timeout.new('SOCKS5 read timeout')
          end
          ready = IO.select([@socket], nil, nil, remaining)
          unless ready
            raise Excon::Error::Timeout.new('SOCKS5 read timeout')
          end
        end

        chunk = @socket.read_nonblock(nbytes - data.bytesize, exception: false)
        case chunk
        when :wait_readable
          IO.select([@socket], nil, nil, deadline ? [deadline - Time.now, 0].max : nil)
        when nil, ''
          raise Excon::Error::Socket.new(Exception.new('SOCKS5 proxy connection closed unexpectedly'))
        else
          data << chunk
        end
      end
      data
    end
  end
end
