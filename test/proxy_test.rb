# frozen_string_literal: true

require_relative 'test_helper'

# How Excon.new reads the :proxy option. No requests are sent.
class ProxyConfigTest < Minitest::Test
  include WithoutProxyEnv

  def test_no_proxy
    assert_nil Excon.new('http://foo.com').data[:proxy]
  end

  def test_empty_proxy_is_no_proxy
    assert_nil Excon.new('http://foo.com', proxy: '').data[:proxy]
  end

  def test_fully_specified_proxy
    proxy = Excon.new('http://foo.com', proxy: 'https://myproxy.net:8080').data[:proxy]

    assert_equal 'myproxy.net', proxy[:host]
    assert_equal 8080, proxy[:port]
    assert_equal 'https', proxy[:scheme]
  end

  def test_unix_socket_proxy
    proxy = Excon.new('http://foo.com', proxy: 'unix:///tmp/myproxy.sock').data[:proxy]

    assert_nil proxy[:host]
    assert_nil proxy[:port]
    assert_equal 'unix', proxy[:scheme]
    assert_equal '/tmp/myproxy.sock', proxy[:path]
  end

  def test_proxy_is_parsed_with_uri_parser
    # delegates to URI, recording each string it is asked to parse
    parser = Class.new do
      attr_reader :parsed

      def initialize
        @parsed = []
      end

      def parse(uri)
        @parsed << uri
        URI.parse(uri)
      end
    end.new

    Excon.new('http://foo.com', proxy: 'http://myproxy.net:8080', uri_parser: parser)

    # Excon.new also parses the connection's own URL with it
    assert_includes parser.parsed, 'http://myproxy.net:8080'
  end
end

# How Excon.new reads the proxy environment variables. Each class including
# this sets them in lowercase or uppercase (see proxy_env).
module ProxyFromEnvironmentTests
  PROXY_ENV = {
    'http_proxy' => 'http://myproxy:8080',
    'https_proxy' => 'http://mysecureproxy:8081',
    'no_proxy' => 'noproxy, subdomain.noproxy2, [fc00::1], 10.0.0.1'
  }.freeze

  def setup
    super
    proxy_env.each { |key, value| ENV[key] = value }
  end

  def test_http_connection_uses_http_proxy
    proxy = Excon.new('http://foo.com').data[:proxy]

    assert_equal 'myproxy', proxy[:host]
    assert_equal 8080, proxy[:port]
    assert_equal 'http', proxy[:scheme]
  end

  def test_http_connection_with_disable_proxy
    assert_nil Excon.new('http://foo.com', disable_proxy: true).data[:proxy]
  end

  def test_https_connection_uses_https_proxy
    proxy = Excon.new('https://secret.com').data[:proxy]

    assert_equal 'mysecureproxy', proxy[:host]
    assert_equal 8081, proxy[:port]
    assert_equal 'http', proxy[:scheme]
  end

  def test_https_connection_with_disable_proxy
    assert_nil Excon.new('https://foo.com', disable_proxy: true).data[:proxy]
  end

  def test_environment_overrides_proxy_option
    proxy = Excon.new('http://foo.com', proxy: 'http://hard.coded.proxy:6666').data[:proxy]

    assert_equal 'myproxy', proxy[:host]
    assert_equal 8080, proxy[:port]
  end

  def test_host_under_no_proxy_domain_is_not_proxied
    assert_nil Excon.new('http://somesubdomain.noproxy').data[:proxy]
  end

  # noproxy2 only partly matches subdomain.noproxy2 in no_proxy
  def test_host_partly_matching_no_proxy_is_proxied
    assert_equal 'myproxy', Excon.new('http://noproxy2').data[:proxy][:host]
  end

  def test_host_under_no_proxy_subdomain_is_not_proxied
    assert_nil Excon.new('http://a.subdomain.noproxy2').data[:proxy]
  end
end

class ProxyFromLowercaseEnvironmentTest < Minitest::Test
  include WithoutProxyEnv
  include ProxyFromEnvironmentTests

  def proxy_env
    PROXY_ENV
  end
end

class ProxyFromUppercaseEnvironmentTest < Minitest::Test
  include WithoutProxyEnv
  include ProxyFromEnvironmentTests

  def proxy_env
    PROXY_ENV.transform_keys(&:upcase)
  end
end

class ProxyFromPartialEnvironmentTest < Minitest::Test
  include WithoutProxyEnv

  def test_https_connection_falls_back_to_http_proxy
    ENV['http_proxy'] = 'http://myproxy:8080'
    proxy = Excon.new('https://secret.com').data[:proxy]

    assert_equal 'myproxy', proxy[:host]
    assert_equal 8080, proxy[:port]
    assert_equal 'http', proxy[:scheme]
  end

  def test_unix_socket_proxy_from_environment
    ENV['http_proxy'] = 'unix:///tmp/myproxy.sock'
    proxy = Excon.new('https://secret.com').data[:proxy]

    assert_nil proxy[:host]
    assert_nil proxy[:port]
    assert_equal 'unix', proxy[:scheme]
    assert_equal '/tmp/myproxy.sock', proxy[:path]
  end
end

# How no_proxy entries are matched against the host.
class NoProxyEnvironmentTest < Minitest::Test
  include WithoutProxyEnv

  def setup
    super
    ENV['http_proxy'] = 'http://proxy.example:8080'
  end

  def test_no_proxy_escapes_hostname_regex_metacharacters
    ENV['no_proxy'] = 'sub.example.com'

    assert_nil Excon.new('http://sub.example.com').data[:proxy]
    # the dot in sub.example.com matches only a dot
    assert Excon.new('http://subxexample.com').data[:proxy]
  end

  def test_no_proxy_asterisk_matches_all_hosts
    ENV['no_proxy'] = '*'

    assert_nil Excon.new('http://example.com').data[:proxy]
  end
end

# proxy.ru answers any GET with 'proxied content', reporting the request URI,
# Host and Proxy-Connection it received as the Sent-Request-Uri, Sent-Host
# and Sent-Proxy-Connection headers.
module ProxyRequestHelpers
  private

  def request_through(proxy)
    connection = Excon.new('http://foo.com:8080', proxy: proxy)
    connection.request(method: :get, path: '/bar', query: { alpha: 'kappa' })
  end
end

class ProxyRequestTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ProxyRequestHelpers

  test_server :webrick, 'proxy.ru'

  def test_http_proxying
    response = request_through('http://127.0.0.1:9292')

    assert_equal 200, response.status
    # requests to a proxy must use the absolute form
    assert_equal 'http://foo.com:8080/bar?alpha=kappa', response.headers['Sent-Request-Uri']
    assert_equal 'foo.com:8080', response.headers['Sent-Host']
    assert_equal 'Keep-Alive', response.headers['Sent-Proxy-Connection']
    assert_equal 'proxied content', response.body
  end

  def test_http_proxying_with_proxy_credentials
    response = request_through('http://user:pass@127.0.0.1:9292')

    assert_equal 200, response.status
    assert_equal 'http://foo.com:8080/bar?alpha=kappa', response.headers['Sent-Request-Uri']
    assert_equal 'foo.com:8080', response.headers['Sent-Host']
    assert_equal 'Keep-Alive', response.headers['Sent-Proxy-Connection']
    assert_equal 'proxied content', response.body
  end
end

class ProxyUnixSocketRequestTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ProxyRequestHelpers

  test_server :puma, 'proxy.ru', bind: 'unix:///tmp/myproxy.sock'

  def test_http_proxying_over_unix_socket
    response = request_through('unix:///tmp/myproxy.sock')

    assert_equal 200, response.status
    # absolute form, as over TCP
    assert_equal 'http://foo.com:8080/bar?alpha=kappa', response.headers['Sent-Request-Uri']
    assert_equal 'foo.com:8080', response.headers['Sent-Host']
    assert_equal 'Keep-Alive', response.headers['Sent-Proxy-Connection']
    assert_equal 'proxied content', response.body
  end
end

# An HTTPS connection through a proxy first asks it to open a tunnel with
# CONNECT; FakeHTTPProxy refuses every CONNECT with a 407.
class ProxyConnectRefusedTest < Minitest::Test
  include WithoutProxyEnv

  def setup
    super
    @proxy = FakeHTTPProxy.new(status: '407 Proxy Authentication Required').start
  end

  def teardown
    @proxy.stop
    super
  end

  def test_refused_connect_raises_proxy_connection_error
    error = assert_raises(Excon::Error::ProxyConnectionError) { request }

    assert_equal 'proxy connection could not be established', error.message
  end

  def test_proxy_connection_error_has_proxy_response
    error = assert_raises(Excon::Error::ProxyConnectionError) { request }

    assert_equal 407, error.response[:response][:status]
  end

  def test_proxy_connection_error_has_connect_request
    error = assert_raises(Excon::Error::ProxyConnectionError) { request }

    assert error.request.start_with?("CONNECT foo.com:443 HTTP/1.1\r\n")
  end

  # it was previously raised wrapped in a Socket error, so code may rescue it
  # as one and reach it through socket_error
  def test_proxy_connection_error_is_a_socket_error
    error = assert_raises(Excon::Error::Socket) { request }

    assert_kind_of Excon::Errors::SocketError, error
    assert_same error, error.socket_error
    assert_equal 407, error.socket_error.response[:response][:status]
  end

  # Socket errors are in the default retry_errors
  def test_refused_connect_is_retried_for_idempotent_requests
    assert_raises(Excon::Error::ProxyConnectionError) do
      request(idempotent: true, retry_limit: 2, retry_interval: 0)
    end

    assert_equal 2, @proxy.requests.length
  end

  private

  def request(**params)
    Excon.get('https://foo.com/', proxy: "http://127.0.0.1:#{@proxy.port}", **params)
  end
end
