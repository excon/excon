# frozen_string_literal: true

require_relative 'test_helper'

# NUL, CR or LF in a request's method, host, path or query could end the
# request line early and inject headers (or, for a host, inject into an HTTPS
# proxy's CONNECT), so Excon raises a subclass of Excon::Error::InvalidParameter
# before it connects.
#
# These requests go to a port nothing listens on, so nothing can reach a
# server: if a check ran after connecting, the test would get an
# Excon::Error::Socket instead.
class UnsafeCharsTest < Minitest::Test
  include WithoutProxyEnv

  def setup
    super
    @proxies = []
  end

  def teardown
    @proxies.each(&:stop)
    super
  end

  # path

  def test_path_with_crlf_raises_invalid_path
    assert_raises(Excon::Error::InvalidPath) do
      connection.request(path: "/foo\r\nBar: baz")
    end
  end

  def test_path_with_nul_raises_invalid_path
    assert_raises(Excon::Error::InvalidPath) do
      connection.request(path: "/foo\0")
    end
  end

  def test_path_with_invalid_encoding_and_crlf_raises_invalid_path
    # "\xFF" isn't valid UTF-8; a Regexp match on it would raise ArgumentError
    assert_raises(Excon::Error::InvalidPath) do
      connection.request(path: "/\xFF\r\nBar: baz")
    end
  end

  def test_invalid_path_message_includes_the_path
    error = assert_raises(Excon::Error::InvalidPath) do
      connection.request(path: "/foo\r\nBar: baz")
    end
    assert_includes error.message, '"/foo\r\nBar: baz"'
  end

  # query

  def test_string_query_with_crlf_raises_invalid_query
    assert_raises(Excon::Error::InvalidQuery) do
      connection.request(path: '/', query: "a=1\r\nBar: baz")
    end
  end

  def test_invalid_query_message_leaves_out_the_query
    # a query may carry a token, so the message doesn't show it
    error = assert_raises(Excon::Error::InvalidQuery) do
      connection.request(path: '/', query: "token=secret\r\nBar: baz")
    end
    refute_includes error.message, 'secret'
  end

  # method

  def test_method_with_crlf_raises_invalid_method
    assert_raises(Excon::Error::InvalidMethod) do
      connection.request(method: "GET\r\nBar: baz", path: '/')
    end
  end

  # host

  # :host is a connection param, not a request one; :hostname (what is
  # connected to) stays 127.0.0.1
  def test_host_with_crlf_raises_invalid_host
    http = Excon.new("http://127.0.0.1:#{refused_port}", host: "127.0.0.1\r\nBar: baz")

    assert_raises(Excon::Error::InvalidHost) do
      http.request(path: '/')
    end
  end

  def test_host_with_crlf_is_not_sent_in_a_proxy_connect
    proxy = FakeHTTPProxy.new.start
    @proxies << proxy
    https = Excon.new("https://127.0.0.1:#{refused_port}", host: "127.0.0.1\r\nBar: baz",
                                                            proxy: "http://127.0.0.1:#{proxy.port}")

    assert_raises(Excon::Error::InvalidHost) do
      https.request(path: '/')
    end
    # raised before the CONNECT, which would carry the host to the proxy
    assert_empty proxy.requests
  end

  private

  def connection
    @connection ||= Excon.new("http://127.0.0.1:#{refused_port}")
  end

  # A port nothing listens on at 127.0.0.1.
  def refused_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server&.close
  end
end

# The header checks run after connecting, but still before anything is
# written. These connect to a server that records what it receives, to check
# that nothing reaches it. (A Hash query with these chars is escaped rather
# than rejected; see test/query_string_test.rb.)
class UnsafeCharsHeaderTest < Minitest::Test
  include WithoutProxyEnv

  def setup
    super
    @server = TCPServer.new('127.0.0.1', 0)
    @received = +''
    @server_thread = Thread.new do
      client = @server.accept
      @received << client.read # until Excon closes the connection
      client.close
    end
    # the server never answers, so if a request were sent, fail fast
    @connection = Excon.new("http://127.0.0.1:#{@server.addr[1]}", read_timeout: 1)
  end

  def teardown
    @server_thread.kill.join
    @server.close
    super
  end

  def test_header_key_with_nul_raises_invalid_header_key
    assert_raises(Excon::Error::InvalidHeaderKey) do
      @connection.request(path: '/', headers: { "Foo\0" => 'bar' })
    end
    assert_empty received
  end

  def test_header_value_with_nul_raises_invalid_header_value
    assert_raises(Excon::Error::InvalidHeaderValue) do
      @connection.request(path: '/', headers: { Foo: "bar\0" })
    end
    assert_empty received
  end

  def test_header_value_in_an_array_with_crlf_raises_invalid_header_value
    # each value of an Array is sent as its own header line
    assert_raises(Excon::Error::InvalidHeaderValue) do
      @connection.request(path: '/', headers: { Foo: ['bar', "baz\r\nQux: quux"] })
    end
    assert_empty received
  end

  def test_header_value_with_invalid_encoding_and_crlf_raises_invalid_header_value
    # "\xFF" isn't valid UTF-8; a Regexp match on it would raise ArgumentError
    assert_raises(Excon::Error::InvalidHeaderValue) do
      @connection.request(path: '/', headers: { Foo: "\xFFbar\r\nBaz: qux" })
    end
    assert_empty received
  end

  def test_invalid_header_value_message_leaves_out_the_value
    # a header value may be a credential, so the message names only the header
    error = assert_raises(Excon::Error::InvalidHeaderValue) do
      @connection.request(path: '/', headers: { Authorization: "secret\r\nBar: baz" })
    end
    assert_includes error.message, '"Authorization"'
    refute_includes error.message, 'secret'
  end

  private

  # What the server received, once Excon has closed the connection.
  def received
    @connection.reset
    assert @server_thread.join(5), 'the server is still reading'
    @received
  end
end
