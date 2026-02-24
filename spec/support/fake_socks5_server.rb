# frozen_string_literal: true

require 'socket'

module Excon
  module Test
    class FakeSOCKS5Server
      attr_reader :port, :host

      def initialize(options = {})
        @host = options[:host] || '127.0.0.1'
        @port = options[:port] || 0
        @username = options[:username]
        @password = options[:password]
        @reject_auth = options[:reject_auth] || false
        @reject_connect = options[:reject_connect] || false
        @threads = []
        @running = false
      end

      def start
        @server = TCPServer.new(@host, @port)
        @port = @server.addr[1]
        @running = true
        @accept_thread = Thread.new { accept_loop }
      end

      def stop
        @running = false
        @server&.close rescue nil
        @accept_thread&.join(2)
        @threads.each { |t| t.kill rescue nil }
      end

      private

      def accept_loop
        while @running
          begin
            client = @server.accept
            @threads << Thread.new(client) { |c| handle_client(c) }
          rescue IOError
            break
          end
        end
      end

      def handle_client(client)
        upstream = nil

        # SOCKS5 greeting
        greeting = client.read(2)
        return unless greeting && greeting.bytesize == 2
        _version, nmethods = greeting.unpack('CC')
        methods = client.read(nmethods)
        return unless methods

        if @username && @password
          # Require username/password auth (method 0x02)
          client.write([0x05, 0x02].pack('CC'))

          # Read auth sub-negotiation (RFC 1929)
          auth_version = client.read(1)&.unpack1('C')
          return unless auth_version

          ulen = client.read(1)&.unpack1('C')
          return unless ulen
          username = client.read(ulen)

          plen = client.read(1)&.unpack1('C')
          return unless plen
          password = client.read(plen)

          if @reject_auth || username != @username || password != @password
            client.write([0x01, 0x01].pack('CC'))
            return
          end
          client.write([0x01, 0x00].pack('CC'))
        else
          # No authentication required
          client.write([0x05, 0x00].pack('CC'))
        end

        # SOCKS5 CONNECT request
        header = client.read(4)
        return unless header && header.bytesize == 4
        _version, _cmd, _rsv, atyp = header.unpack('CCCC')

        target_host = case atyp
        when 0x01 # IPv4
          raw = client.read(4)
          return unless raw
          raw.unpack('C4').join('.')
        when 0x03 # Domain
          len = client.read(1)&.unpack1('C')
          return unless len
          client.read(len)
        when 0x04 # IPv6
          client.read(16)
        end
        return unless target_host

        port_data = client.read(2)
        return unless port_data
        target_port = port_data.unpack1('n')

        if @reject_connect
          # Reply: connection refused (0x05)
          client.write([0x05, 0x05, 0x00, 0x01].pack('CCCC') + "\0\0\0\0" + [0].pack('n'))
          return
        end

        # Connect to the actual target
        begin
          upstream = TCPSocket.new(target_host, target_port)
        rescue => _e
          # Reply: host unreachable (0x04)
          client.write([0x05, 0x04, 0x00, 0x01].pack('CCCC') + "\0\0\0\0" + [0].pack('n'))
          return
        end

        # Reply: success
        client.write([0x05, 0x00, 0x00, 0x01].pack('CCCC') + "\0\0\0\0" + [0].pack('n'))

        # Bidirectional forwarding
        forward_data(client, upstream)
      ensure
        client&.close rescue nil
        upstream&.close rescue nil
      end

      def forward_data(client, upstream)
        loop do
          ready = IO.select([client, upstream], nil, nil, 5)
          break unless ready

          ready[0].each do |sock|
            begin
              data = sock.read_nonblock(65536)
              if sock == client
                upstream.write(data)
              else
                client.write(data)
              end
            rescue EOFError, IOError, Errno::ECONNRESET
              return
            end
          end
        end
      end
    end
  end
end
