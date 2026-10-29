# frozen_string_literal: true

require_relative 'test_helper'

# On macOS 27 a socket's second connect_nonblock raises EISCONN even when the
# nonblocking connect failed, so Excon::Socket#connect checks SO_ERROR first.
#
# Records the sockets a test's thread connects. With eisconn set, a socket's
# second connect_nonblock raises EISCONN without calling connect(2), leaving
# the connect's error in SO_ERROR as on macOS 27. With so_error set, a
# recorded socket reports that errno as its SO_ERROR.
module ConnectNonblockRecorder
  Recording = Struct.new(:eisconn, :sockets, :so_error, :after_connect_started)

  def connect_nonblock(*, **)
    recording = Thread.current[:connect_nonblock_recording]
    return super unless recording
    raise Errno::EISCONN if recording.eisconn && recording.sockets.include?(self)

    recording.sockets << self unless recording.sockets.include?(self)
    begin
      super
    rescue IO::WaitWritable
      recording.after_connect_started&.call(self)
      raise
    end
  end

  # Reads the real option first, so SO_ERROR is caught however it's named.
  def getsockopt(*)
    option = super
    recording = Thread.current[:connect_nonblock_recording]
    return option unless recording&.so_error && recording.sockets.include?(self) &&
                         option.level == Socket::SOL_SOCKET && option.optname == Socket::SO_ERROR

    Socket::Option.int(option.family, option.level, option.optname, recording.so_error)
  end
end
Socket.prepend(ConnectNonblockRecorder)

module RefusedConnectTestHelpers
  # Why the tests that use ::1 can't run here, or nil if they can.
  IPV6_UNAVAILABLE = begin
    TCPServer.new('::1', 0).close
    nil
  rescue SystemCallError => e
    "IPv6 loopback (::1) is unavailable: #{e.message}"
  end

  private

  # A port that nothing listens on at 127.0.0.1, nor at ::1 if there is one.
  def refused_port
    server = IPV6_UNAVAILABLE ? TCPServer.new('127.0.0.1', 0) : listen_on_ipv4_only
    server.addr[1]
  ensure
    server&.close
  end

  # Starts a server on 127.0.0.1 that answers each request with a 200, at a
  # port that nothing listens on at ::1, and returns the port.
  def serve_on_ipv4_only
    @server = listen_on_ipv4_only
    @server_thread = Thread.new { loop { answer(@server.accept) } }
    @server.addr[1]
  end

  def answer(client)
    client.readpartial(4096)
    client.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
  ensure
    client.close
  end

  # Starts a server on 127.0.0.1 that accepts one connection and resets it,
  # by closing it with a zero linger time, and returns its port.
  def serve_and_reset
    @server = TCPServer.new('127.0.0.1', 0)
    @server_thread = Thread.new do
      client = @server.accept
      client.setsockopt(Socket::Option.linger(true, 0))
      client.close
    end
    @server.addr[1]
  end

  # A TCPServer on 127.0.0.1, at a port that nothing listens on at ::1.
  def listen_on_ipv4_only
    loop do
      server = TCPServer.new('127.0.0.1', 0)
      begin
        TCPServer.new('::1', server.addr[1]).close
        return server
      rescue Errno::EADDRINUSE
        server.close
      end
    end
  end
end

# Failed connects, included below with and without eisconn.
module RefusedConnectTests
  include RefusedConnectTestHelpers

  # A resolv_resolver that gives every name the same addresses, in order.
  Addresses = Struct.new(:addresses) do
    def each_address(_name, &)
      addresses.each(&)
    end
  end

  def setup
    super
    @recording = ConnectNonblockRecorder::Recording.new(eisconn?, [])
    Thread.current[:connect_nonblock_recording] = @recording
  end

  def teardown
    Thread.current[:connect_nonblock_recording] = nil
    @recording.sockets.each { |socket| socket.close unless socket.closed? }
    @server_thread&.kill&.join
    @server&.close
    super
  end

  def test_refused_connect_raises_connection_refused
    port = refused_port

    error = assert_raises(Excon::Error::Socket) { Excon.get("http://127.0.0.1:#{port}/") }
    assert_kind_of Errno::ECONNREFUSED, error.socket_error
    # raised by the connect, not by a write to a socket taken as connected
    assert_includes error.message, "connect(2) for 127.0.0.1:#{port}"
  end

  def test_refused_ipv6_connect_names_the_address_in_brackets
    skip IPV6_UNAVAILABLE if IPV6_UNAVAILABLE

    port = refused_port

    error = assert_raises(Excon::Error::Socket) { Excon.get("http://[::1]:#{port}/") }
    assert_kind_of Errno::ECONNREFUSED, error.socket_error
    assert_includes error.message, "connect(2) for [::1]:#{port}"
  end

  def test_refused_connect_closes_its_socket
    assert_raises(Excon::Error::Socket) { Excon.get("http://127.0.0.1:#{refused_port}/") }

    assert_equal 1, @recording.sockets.length
    assert @recording.sockets.first.closed?
  end

  def test_refused_address_falls_back_to_the_next_address
    skip IPV6_UNAVAILABLE if IPV6_UNAVAILABLE

    port = serve_on_ipv4_only

    # localhost as Resolv::Hosts gives it, reversing the hosts file's order
    response = Excon.get("http://excon.test:#{port}/", resolv_resolver: Addresses.new(['::1', '127.0.0.1']))
    assert_equal 200, response.status
    assert_equal '127.0.0.1', response.remote_ip
  end

  def test_all_addresses_refused_raises_the_last_error
    skip IPV6_UNAVAILABLE if IPV6_UNAVAILABLE

    port = refused_port

    error = assert_raises(Excon::Error::Socket) do
      Excon.get("http://excon.test:#{port}/", resolv_resolver: Addresses.new(['::1', '127.0.0.1']))
    end
    assert_kind_of Errno::ECONNREFUSED, error.socket_error
    assert_includes error.message, "connect(2) for 127.0.0.1:#{port}"
  end

  def test_reset_before_the_result_is_read_raises_the_reset
    skip 'not verified on JRuby' if RUBY_PLATFORM == 'java'

    port = serve_and_reset
    # a reset makes the socket readable, and waiting for it leaves SO_ERROR set
    @recording.after_connect_started = lambda do |socket|
      assert socket.wait_readable(5), 'the server did not reset the connection'
    end

    error = assert_raises(Excon::Error::Socket) { Excon.get("http://127.0.0.1:#{port}/") }
    assert_kind_of Errno::ECONNRESET, error.socket_error
    assert_includes error.message, "connect(2) for 127.0.0.1:#{port}"
  end
end

class RefusedConnectTest < Minitest::Test
  include WithoutProxyEnv
  include RefusedConnectTests

  def eisconn?
    false
  end
end

class RefusedConnectEisconnTest < Minitest::Test
  include WithoutProxyEnv
  include RefusedConnectTests

  def eisconn?
    true
  end

  # What this class's other tests rely on, checked without Excon.
  def test_simulated_second_connect_leaves_the_refusal_in_so_error
    sockaddr = Socket.sockaddr_in(refused_port, '127.0.0.1')
    socket = Socket.new(:INET, :STREAM)

    assert_raises(IO::WaitWritable) { socket.connect_nonblock(sockaddr) }
    # Excon::Socket waits with IO.select, so this does too
    writable = IO.select(nil, [socket], nil, 5) # rubocop:disable Lint/IncompatibleIoSelectWithFiberScheduler
    assert writable, 'the connect is still in progress'
    assert_raises(Errno::EISCONN) { socket.connect_nonblock(sockaddr) }
    assert_equal Errno::ECONNREFUSED::Errno, socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR).int
  end

  def test_other_connect_errors_are_raised_as_they_are
    # a connect error loopback can't produce, as when ARP gets no answer
    @recording.so_error = Errno::EHOSTUNREACH::Errno
    port = refused_port

    error = assert_raises(Excon::Error::Socket) { Excon.get("http://127.0.0.1:#{port}/") }
    assert_kind_of Errno::EHOSTUNREACH, error.socket_error
    assert_includes error.message, "connect(2) for 127.0.0.1:#{port}"
  end
end
