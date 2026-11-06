# frozen_string_literal: true

require_relative 'test_helper'
require 'webrick'
require 'webrick/httpproxy'

# An HTTPS connection through an HTTP proxy first sends the proxy a CONNECT
# request for the target's host and port, then (once the proxy answers 200)
# does the TLS handshake and its requests through that tunnel.
#
# These reach ssl.ru (basic.ru over HTTPS on 127.0.0.1:9443) through a proxy
# each test starts: FakeHTTPProxy (see test/support/fake_http_proxy.rb), which
# records the CONNECT requests it receives, or WEBrick::HTTPProxyServer.
module ProxyConnectHelpers
  TARGET = 'https://127.0.0.1:9443'

  def setup
    super
    @proxies = []
  end

  def teardown
    @proxies.each(&:stop)
    super
  end

  private

  def start_fake_proxy(**options)
    FakeHTTPProxy.new(**options).start.tap { |proxy| @proxies << proxy }
  end

  # params are passed to Excon.new. The short timeouts make a request the
  # proxy can't make sense of fail rather than hang.
  def connection(proxy, **params)
    Excon.new(TARGET, proxy: proxy, ssl_verify_peer: true, ssl_ca_file: data_path('127.0.0.1.cert.crt'),
                      connect_timeout: 5, read_timeout: 5, **params)
  end

  # the CONNECT request proxy received, split into its request line and headers
  def connect_request_lines(proxy)
    assert_equal 1, proxy.requests.length
    proxy.requests.first.split("\r\n")
  end
end

class ProxyConnectTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ProxyConnectHelpers

  test_server :webrick, 'ssl.ru'

  def test_https_request_is_tunneled
    proxy = start_fake_proxy
    response = connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/content-length/100')

    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_post_body_is_tunneled
    proxy = start_fake_proxy
    response = connection("http://127.0.0.1:#{proxy.port}").request(method: :post, path: '/echo', body: 'tunneled')

    assert_equal 'tunneled', response.body
  end

  def test_connect_names_target_host_and_port
    proxy = start_fake_proxy
    connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    lines = connect_request_lines(proxy)

    assert_equal 'CONNECT 127.0.0.1:9443 HTTP/1.1', lines.first
    assert_includes lines, 'Host: 127.0.0.1:9443'
  end

  def test_connect_sends_proxy_connection_keep_alive
    proxy = start_fake_proxy
    connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')

    assert_includes connect_request_lines(proxy), 'Proxy-Connection: Keep-Alive'
  end

  def test_connect_without_proxy_credentials_sends_no_proxy_authorization
    proxy = start_fake_proxy
    connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')

    assert_empty(connect_request_lines(proxy).grep(/\AProxy-Authorization:/i))
  end

  def test_connect_sends_proxy_credentials
    proxy = start_fake_proxy
    connection("http://user:pass@127.0.0.1:#{proxy.port}").request(method: :get, path: '/')

    # base64 of 'user:pass'
    assert_includes connect_request_lines(proxy), 'Proxy-Authorization: Basic dXNlcjpwYXNz'
  end

  def test_connect_sends_ssl_proxy_headers
    proxy = start_fake_proxy
    connection("http://127.0.0.1:#{proxy.port}", ssl_proxy_headers: { 'X-Proxy-Token' => 'secret' })
      .request(method: :get, path: '/')

    assert_includes connect_request_lines(proxy), 'X-Proxy-Token: secret'
  end

  # the proxy headers belong to the CONNECT, not to requests in the tunnel,
  # which the proxy can't read
  def test_tunneled_request_has_no_proxy_headers
    proxy = start_fake_proxy
    conn = connection("http://user:pass@127.0.0.1:#{proxy.port}", ssl_proxy_headers: { 'X-Proxy-Token' => 'secret' })
    response = conn.request(method: :get, path: '/headers')
    # /headers reports the request's headers as rack env keys
    headers = JSON.parse(response.body)

    refute_includes headers, 'HTTP_PROXY_AUTHORIZATION'
    refute_includes headers, 'HTTP_PROXY_CONNECTION'
    refute_includes headers, 'HTTP_X_PROXY_TOKEN'
  end

  # any 2xx answer to CONNECT opens the tunnel (RFC 9110, section 9.3.6)
  def test_connect_answered_with_any_2xx_is_tunneled
    proxy = start_fake_proxy(status: '201 Created')
    response = connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/foo')

    assert_equal 200, response.status
    assert_equal 'foo', response.body
  end

  # the proxy can't read requests in the tunnel, so they name only the path,
  # as when not proxied
  def test_tunneled_request_uses_relative_uri
    proxy = start_fake_proxy(terminate_tls: true)
    connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/foo', query: { a: 'b' })
    connect, tunneled = proxy.requests

    assert connect.start_with?('CONNECT 127.0.0.1:9443 HTTP/1.1')
    assert_equal 'GET /foo?a=b HTTP/1.1', tunneled.lines.first.chomp
  end

  def test_persistent_connection_reuses_tunnel
    proxy = start_fake_proxy
    conn = connection("http://127.0.0.1:#{proxy.port}", persistent: true)

    assert_equal 'foo', conn.request(method: :get, path: '/foo').body
    assert_equal 'bar', conn.request(method: :get, path: '/bar').body
    assert_equal 1, proxy.requests.length
  ensure
    conn&.reset
  end

  def test_non_persistent_connection_opens_a_tunnel_per_request
    proxy = start_fake_proxy
    conn = connection("http://127.0.0.1:#{proxy.port}")
    conn.request(method: :get, path: '/foo')
    conn.request(method: :get, path: '/bar')

    assert_equal 2, proxy.requests.length
  end

  # the certificate checked is the target's, received through the tunnel
  def test_target_certificate_is_verified_through_tunnel
    proxy = start_fake_proxy
    # excon.cert.crt did not sign the target's certificate
    conn = connection("http://127.0.0.1:#{proxy.port}", ssl_ca_file: data_path('excon.cert.crt'))

    assert_raises(Excon::Error::Certificate) { conn.request(method: :get, path: '/') }
  end
end

# Proxies that fail to open the tunnel. Nothing is reached through them.
class ProxyConnectFailureTest < Minitest::Test
  include WithoutProxyEnv
  include ProxyConnectHelpers

  def test_proxy_closing_without_answering_raises_socket_error
    proxy = start_fake_proxy(reply: '')

    assert_raises(Excon::Error::Socket) do
      connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    end
  end

  def test_proxy_answering_without_a_status_line_raises_socket_error
    proxy = start_fake_proxy(reply: "garbage\r\n\r\n")

    assert_raises(Excon::Error::Socket) do
      connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    end
  end

  def test_proxy_not_answering_raises_timeout
    proxy = start_fake_proxy(silent: true)

    assert_raises(Excon::Error::Timeout) do
      connection("http://127.0.0.1:#{proxy.port}", read_timeout: 0.5).request(method: :get, path: '/')
    end
  end

  # the error keeps the CONNECT request, which may be logged
  def test_proxy_connection_error_request_redacts_proxy_credentials
    proxy = start_fake_proxy(status: '407 Proxy Authentication Required')
    error = assert_raises(Excon::Error::ProxyConnectionError) do
      connection("http://user:pass@127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    end

    # base64 of 'user:pass', which the proxy itself was sent
    assert_includes proxy.requests.first, 'Proxy-Authorization: Basic dXNlcjpwYXNz'
    assert_includes error.request, "Proxy-Authorization: REDACTED\r\n"
    refute_includes error.request, 'dXNlcjpwYXNz'
  end

  def test_proxy_connection_error_request_redacts_credentials_in_ssl_proxy_headers
    proxy = start_fake_proxy(status: '407 Proxy Authentication Required')
    conn = connection("http://127.0.0.1:#{proxy.port}", ssl_proxy_headers: { 'proxy-authorization' => 'Bearer secret' })
    error = assert_raises(Excon::Error::ProxyConnectionError) { conn.request(method: :get, path: '/') }

    assert_includes error.request, "proxy-authorization: REDACTED\r\n"
    refute_includes error.request, 'secret'
  end

  def test_proxy_connection_error_request_keeps_other_headers
    proxy = start_fake_proxy(status: '407 Proxy Authentication Required')
    error = assert_raises(Excon::Error::ProxyConnectionError) do
      connection("http://user:pass@127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    end

    assert error.request.start_with?("CONNECT 127.0.0.1:9443 HTTP/1.1\r\nHost: 127.0.0.1:9443\r\n")
    assert_includes error.request, "Proxy-Connection: Keep-Alive\r\n"
  end

  def test_proxy_refusing_connect_raises_proxy_connection_error
    proxy = start_fake_proxy(status: '403 Forbidden')
    error = assert_raises(Excon::Error::ProxyConnectionError) do
      connection("http://127.0.0.1:#{proxy.port}").request(method: :get, path: '/')
    end

    assert_equal 403, error.response[:response][:status]
  end
end

# The same through WEBrick::HTTPProxyServer, a real proxy, which requires the
# credentials user:pass when started with auth: true.
module WEBrickProxyHelpers
  private

  def start_webrick_proxy(auth: false)
    options = { BindAddress: '127.0.0.1', Port: 0, Logger: WEBrick::Log.new(File::NULL), AccessLog: [] }
    if auth
      options[:ProxyAuthProc] = lambda do |request, response|
        WEBrick::HTTPAuth.proxy_basic_auth(request, response, 'proxy') { |user, pass| user == 'user' && pass == 'pass' }
      end
    end
    proxy = WEBrick::HTTPProxyServer.new(options)
    Thread.new { proxy.start }
    @proxies << WEBrickProxy.new(proxy)
    "127.0.0.1:#{proxy.config[:Port]}"
  end

  # gives a WEBrick proxy the #stop the helpers' teardown calls
  WEBrickProxy = Struct.new(:server) do
    def stop
      server.shutdown
    end
  end
end

class WEBrickProxyConnectTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ProxyConnectHelpers
  include WEBrickProxyHelpers

  test_server :webrick, 'ssl.ru'

  def test_https_request
    address = start_webrick_proxy
    response = connection("http://#{address}").request(method: :get, path: '/content-length/100')

    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_https_request_with_proxy_credentials
    address = start_webrick_proxy(auth: true)
    response = connection("http://user:pass@#{address}").request(method: :get, path: '/foo')

    assert_equal 'foo', response.body
  end

  def test_wrong_proxy_credentials_raise_proxy_connection_error
    address = start_webrick_proxy(auth: true)
    error = assert_raises(Excon::Error::ProxyConnectionError) do
      connection("http://user:wrong@#{address}").request(method: :get, path: '/foo')
    end

    assert_equal 407, error.response[:response][:status]
  end

  def test_missing_proxy_credentials_raise_proxy_connection_error
    address = start_webrick_proxy(auth: true)
    error = assert_raises(Excon::Error::ProxyConnectionError) do
      connection("http://#{address}").request(method: :get, path: '/foo')
    end

    assert_equal 407, error.response[:response][:status]
  end

  def test_persistent_connection
    address = start_webrick_proxy
    conn = connection("http://#{address}", persistent: true)

    assert_equal 'foo', conn.request(method: :get, path: '/foo').body
    assert_equal 'bar', conn.request(method: :get, path: '/bar').body
  ensure
    conn&.reset
  end
end

# Plain HTTP through WEBrick::HTTPProxyServer, which forwards each request to
# basic.ru on 127.0.0.1:9292.
class WEBrickProxyHTTPTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ProxyConnectHelpers
  include WEBrickProxyHelpers

  test_server :webrick, 'basic.ru'

  def test_http_request
    address = start_webrick_proxy
    response = http_connection("http://#{address}").request(method: :get, path: '/foo')

    assert_equal 200, response.status
    assert_equal 'foo', response.body
  end

  def test_http_request_with_proxy_credentials
    address = start_webrick_proxy(auth: true)
    response = http_connection("http://user:pass@#{address}").request(method: :get, path: '/foo')

    assert_equal 'foo', response.body
  end

  # over plain HTTP the proxy's refusal is an ordinary response
  def test_wrong_proxy_credentials_return_proxy_authentication_required
    address = start_webrick_proxy(auth: true)
    response = http_connection("http://user:wrong@#{address}").request(method: :get, path: '/foo')

    assert_equal 407, response.status
  end

  def test_post_body_is_forwarded
    address = start_webrick_proxy
    response = http_connection("http://#{address}").request(method: :post, path: '/echo', body: 'forwarded')

    assert_equal 'forwarded', response.body
  end

  private

  def http_connection(proxy)
    Excon.new('http://127.0.0.1:9292', proxy: proxy, connect_timeout: 5, read_timeout: 5)
  end
end
