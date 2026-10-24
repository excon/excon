# frozen_string_literal: true

require 'socket'

# A minimal SOCKS5 proxy (RFC 1928) for testing, listening on a free port of
# 127.0.0.1 in a thread of the test process. It supports CONNECT only, and
# username/password auth (RFC 1929) when given credentials.
#
#   proxy = FakeSOCKS5Server.new(username: 'user', password: 'pass').start
#   Excon.get('http://127.0.0.1:9292/', socks5_proxy: "user:pass@127.0.0.1:#{proxy.port}")
#   proxy.stop
#
# reject_connect: true answers every CONNECT with "connection refused".
class FakeSOCKS5Server
  VERSION = 0x05
  NO_AUTH = 0x00
  USERNAME_PASSWORD = 0x02
  IPV4 = 0x01
  DOMAIN = 0x03
  IPV6 = 0x04
  SUCCEEDED = 0x00
  HOST_UNREACHABLE = 0x04
  CONNECTION_REFUSED = 0x05

  attr_reader :port

  def initialize(username: nil, password: nil, reject_connect: false)
    @username = username
    @password = password
    @reject_connect = reject_connect
    @threads = []
  end

  def start
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @accept_thread = Thread.new { accept_loop }
    self
  end

  def stop
    @server&.close
    @accept_thread&.join(2)
    @threads.each(&:kill)
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      @threads << Thread.new(client) { |c| handle_client(c) }
    end
  rescue IOError # closed by stop
    nil
  end

  def handle_client(client)
    return unless negotiate_auth(client)

    target = read_connect_request(client)
    return reply(client, CONNECTION_REFUSED) if @reject_connect

    upstream = connect(client, target)
    forward(client, upstream) unless upstream.nil?
  rescue IOError, SystemCallError
    nil # the client went away (EOFError is an IOError)
  ensure
    client.close
    upstream&.close
  end

  # Returns whether the client may go on to send a request.
  def negotiate_auth(client)
    _version, nmethods = read!(client, 2).unpack('CC')
    read!(client, nmethods)
    client.write([VERSION, @username.nil? ? NO_AUTH : USERNAME_PASSWORD].pack('CC'))
    return true if @username.nil?

    read!(client, 1) # auth version
    username = read_string(client)
    password = read_string(client)
    ok = username == @username && password == @password
    client.write([0x01, ok ? 0x00 : 0x01].pack('CC'))
    ok
  end

  # Returns [host, port].
  def read_connect_request(client)
    host =
      case read!(client, 4).getbyte(3) # address type
      when IPV4 then read!(client, 4).unpack('C4').join('.')
      when DOMAIN then read_string(client)
      when IPV6 then read!(client, 16).unpack('n8').map { |group| group.to_s(16) }.join(':')
      end
    [host, read!(client, 2).unpack1('n')]
  end

  # Returns the socket to the target, or nil if it can't be reached.
  def connect(client, target)
    upstream = TCPSocket.new(*target)
    reply(client, SUCCEEDED)
    upstream
  rescue SystemCallError, SocketError
    reply(client, HOST_UNREACHABLE)
    nil
  end

  def read!(client, length)
    data = client.read(length)
    raise EOFError if data.nil? || data.bytesize < length

    data
  end

  # Reads a string prefixed with its length in one byte.
  def read_string(client)
    read!(client, read!(client, 1).unpack1('C'))
  end

  # Replies with a bound address of 0.0.0.0:0.
  def reply(client, status)
    client.write([VERSION, status, 0x00, IPV4, 0, 0, 0, 0, 0].pack('C8n'))
  end

  def forward(client, upstream)
    peers = { client => upstream, upstream => client }
    loop do
      readable, = IO.select(peers.keys, nil, nil, 5)
      break if readable.nil?

      readable.each { |socket| peers[socket].write(socket.read_nonblock(65_536)) }
    end
  rescue EOFError
    nil # either side closed
  end
end
