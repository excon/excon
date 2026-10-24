# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/fake_socks5_server'

class SOCKS5Test < Minitest::Test
  # parse_socks5_proxy returns [host, port, user, pass]

  def test_parses_host_and_port
    assert_equal ['proxy.example.com', '1080', nil, nil], parse('proxy.example.com:1080')
  end

  def test_port_defaults_to_socks_port
    assert_equal ['proxy.example.com', '1080', nil, nil], parse('proxy.example.com')
  end

  def test_parses_credentials
    assert_equal ['proxy.example.com', '1080', 'myuser', 'mypass'], parse('myuser:mypass@proxy.example.com:1080')
  end

  def test_parses_socks5_scheme
    assert_equal ['proxy.example.com', '1080', nil, nil], parse('socks5://proxy.example.com:1080')
  end

  def test_parses_socks5_scheme_with_credentials
    assert_equal ['proxy.example.com', '9050', 'myuser', 'mypass'],
                 parse('socks5://myuser:mypass@proxy.example.com:9050')
  end

  def test_password_may_contain_colons
    _host, _port, user, pass = parse('user:p:a:ss@host:1080')
    assert_equal 'user', user
    assert_equal 'p:a:ss', pass
  end

  def test_socks5_proxy_is_a_valid_connection_key
    connection = Excon.new('http://example.com', socks5_proxy: 'localhost:1080', mock: true)
    assert_equal 'localhost:1080', connection.data[:socks5_proxy]
  end

  def test_socks5_socket_is_a_socket
    assert_equal Excon::Socket, Excon::SOCKS5Socket.superclass
  end

  def test_socks5_ssl_socket_is_an_ssl_socket
    assert_equal Excon::SSLSocket, Excon::SOCKS5SSLSocket.superclass
  end

  private

  def parse(proxy)
    Class.new { include Excon::SOCKS5 }.new.send(:parse_socks5_proxy, proxy)
  end
end

# Each test starts its own proxy, which the class's server (basic.ru, with
# GET /content-length/100 and POST /echo) is reached through.
module SOCKS5ProxyHelpers
  def setup
    super
    @proxies = []
  end

  def teardown
    @proxies.each(&:stop)
    super
  end

  private

  def start_proxy(**options)
    FakeSOCKS5Server.new(**options).start.tap { |proxy| @proxies << proxy }
  end
end

class SOCKS5HTTPTest < Minitest::Test
  include TestServer
  include SOCKS5ProxyHelpers

  test_server :webrick, 'basic.ru'

  def test_get
    response = connection(socks5_proxy: proxy).request(method: :get, path: '/content-length/100')
    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_remote_ip_is_the_proxy
    response = connection(socks5_proxy: proxy).request(method: :get, path: '/content-length/100')
    assert_equal '127.0.0.1', response.remote_ip
  end

  def test_post_body_is_forwarded
    response = connection(socks5_proxy: proxy).request(method: :post, path: '/echo', body: 'hello SOCKS5')
    assert_equal 200, response.status
    assert_equal 'hello SOCKS5', response.body
  end

  def test_blocking_get
    response = connection(socks5_proxy: proxy, nonblock: false).request(method: :get, path: '/content-length/100')
    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_persistent_connection_serves_several_requests
    conn = connection(socks5_proxy: proxy, persistent: true)

    first = conn.request(method: :get, path: '/content-length/100')
    assert_equal 200, first.status
    assert_equal 'x' * 100, first.body

    second = conn.request(method: :post, path: '/echo', body: 'second')
    assert_equal 200, second.status
    assert_equal 'second', second.body
  ensure
    conn&.reset
  end

  def test_authenticates
    proxy = start_proxy(username: 'testuser', password: 'testpass')
    conn = connection(socks5_proxy: "testuser:testpass@127.0.0.1:#{proxy.port}")
    response = conn.request(method: :get, path: '/content-length/100')
    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_authenticates_with_socks5_scheme
    proxy = start_proxy(username: 'testuser', password: 'testpass')
    conn = connection(socks5_proxy: "socks5://testuser:testpass@127.0.0.1:#{proxy.port}")
    response = conn.request(method: :get, path: '/content-length/100')
    assert_equal 200, response.status
  end

  def test_wrong_credentials_raise
    proxy = start_proxy(username: 'testuser', password: 'testpass')
    conn = connection(socks5_proxy: "wrong:creds@127.0.0.1:#{proxy.port}")

    error = assert_raises(Excon::Errors::SocketError) { conn.request(method: :get, path: '/') }
    assert_match(/SOCKS5 proxy authentication failed/, error.message)
  end

  def test_rejected_connect_raises
    proxy = start_proxy(reject_connect: true)
    conn = connection(socks5_proxy: "127.0.0.1:#{proxy.port}")

    error = assert_raises(Excon::Errors::SocketError) { conn.request(method: :get, path: '/') }
    assert_match(/SOCKS5 proxy connect failed/, error.message)
  end

  def test_unreachable_proxy_raises
    # nothing listens on port 1
    conn = connection(socks5_proxy: '127.0.0.1:1', connect_timeout: 1)

    assert_raises(Excon::Error) { conn.request(method: :get, path: '/') }
  end

  def test_hostname_over_255_bytes_raises
    long_host = "#{'a' * 256}.example.com"
    conn = Excon::Connection.new(host: long_host, hostname: long_host, port: 9292, scheme: 'http', socks5_proxy: proxy)

    error = assert_raises(Excon::Errors::SocketError) { conn.request(method: :get, path: '/') }
    assert_match(/hostname exceeds maximum length/, error.message)
  end

  def test_socks5_proxy_takes_precedence_over_proxy
    conn = connection(proxy: 'http://bogus-proxy.invalid:9999', socks5_proxy: proxy)
    assert_equal 200, conn.request(method: :get, path: '/content-length/100').status
  end

  def test_proxy_is_cleared_after_connecting_so_requests_use_relative_uris
    conn = connection(socks5_proxy: proxy)
    conn.request(method: :get, path: '/content-length/100')
    assert_nil conn.data[:proxy]
  end

  private

  def proxy
    "127.0.0.1:#{start_proxy.port}"
  end

  def connection(**)
    Excon.new('http://127.0.0.1:9292', **)
  end
end

class SOCKS5HTTPSTest < Minitest::Test
  include TestServer
  include SOCKS5ProxyHelpers

  test_server :webrick, 'ssl.ru'

  def test_get
    response = connection(ssl_verify_peer: false).request(method: :get, path: '/content-length/100')
    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_post_body_is_forwarded
    response = connection(ssl_verify_peer: false).request(method: :post, path: '/echo', body: 'encrypted payload')
    assert_equal 200, response.status
    assert_equal 'encrypted payload', response.body
  end

  def test_verifies_peer
    conn = connection(ssl_verify_peer: true, ssl_ca_file: data_path('127.0.0.1.cert.crt'))
    assert_equal 200, conn.request(method: :get, path: '/content-length/100').status
  end

  private

  def connection(**)
    Excon.new('https://127.0.0.1:9443', socks5_proxy: "127.0.0.1:#{start_proxy.port}", **)
  end
end
