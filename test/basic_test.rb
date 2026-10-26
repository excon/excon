# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/basic_client_tests'
require_relative 'support/streaming_client_tests'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Plain HTTP requests against tests/rackups/basic.ru.
class BasicTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'basic.ru'

  def explicit_connection
    Excon::Connection.new(
      host: '127.0.0.1',
      hostname: '127.0.0.1',
      nonblock: false,
      port: 9292,
      scheme: 'http',
      ssl_verify_peer: false
    )
  end

  def test_connection_new_with_explicit_options_returns_a_connection
    assert_instance_of Excon::Connection, explicit_connection
  end

  def test_connection_with_explicit_options_gets_a_response
    response = explicit_connection.request(method: :get, path: '/content-length/100')

    assert_instance_of Excon::Response, response
    assert_equal 200, response.status
  end

  # A Ractor can only read Excon's defaults and constants once they're
  # frozen, and freezing them here would break later tests that change
  # Excon.defaults, so this runs in its own process.
  RACTOR_SCRIPT = <<~RUBY
    require 'excon'

    Excon.defaults.freeze
    Excon.defaults[:middlewares].freeze
    Excon::VALID_CONNECTION_KEYS.freeze
    Excon::VALID_REQUEST_KEYS.freeze

    ractor = Ractor.new { Excon.get('http://127.0.0.1:9292/foo').body }
    print(Ractor.method_defined?(:value) ? ractor.value : ractor.take)
  RUBY

  def test_request_works_inside_a_ractor
    skip 'Ractor is not available on this Ruby (e.g. JRuby)' unless defined?(Ractor)

    lib = File.expand_path('../lib', __dir__)
    output, error, status = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', RACTOR_SCRIPT)

    assert status.success?, error
    assert_equal 'foo', output
  end
end

# Plain HTTP streaming, against tests/rackups/streaming.ru.
class BasicStreamingTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include StreamingClientTests

  test_server :puma, 'streaming.ru'

  def url
    'http://127.0.0.1:9292'
  end
end

# HTTPS streaming, against tests/servers/ssl_streaming.rb.
class BasicSslStreamingTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include StreamingClientTests

  test_server :exec, 'ssl_streaming.rb'

  def url
    'https://127.0.0.1:9292'
  end
end

# tests/rackups/basic_auth.ru wraps basic.ru in basic auth, accepting only
# test_user / test_password.
class BasicAuthTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'basic_auth.ru'

  USER = 'test_user'
  PASSWORD = 'test_password'
  URL = 'http://127.0.0.1:9292'

  def url
    "http://#{USER}:#{PASSWORD}@127.0.0.1:9292"
  end

  # string literals are frozen in this file
  def test_credentials_as_frozen_connection_options_are_accepted
    connection = Excon.new(URL, method: :get, path: '/content-length/100', user: USER, password: PASSWORD)

    assert_equal 200, connection.request.status
  end

  def test_credentials_on_the_request_are_accepted
    connection = Excon.new(URL, method: :get, path: '/content-length/100')

    assert_equal 200, connection.request(user: USER, password: PASSWORD).status
  end

  def test_credentials_on_the_request_override_the_connection
    connection = Excon.new(URL, method: :get, path: '/content-length/100',
                                user: 'incorrect_user', password: 'incorrect_password')

    assert_equal 200, connection.request(user: USER, password: PASSWORD).status
  end

  {
    'correct_user_and_no_password' => 'http://test_user@127.0.0.1:9292',
    'correct_user_and_wrong_password' => 'http://test_user:fake_password@127.0.0.1:9292',
    'wrong_user_and_correct_password' => 'http://fake_user:test_password@127.0.0.1:9292'
  }.each do |name, url|
    define_method("test_#{name}_is_unauthorized") do
      response = Excon.new(url).request(method: :get, path: '/content-length/100')

      assert_equal 401, response.status
    end
  end
end

# tests/rackups/ssl.ru serves basic.ru over HTTPS on port 9443, with a
# certificate for 127.0.0.1.
class BasicSslTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'ssl.ru'

  def url
    'https://127.0.0.1:9443'
  end

  def test_verify_peer_with_a_ca_file_succeeds
    connection = Excon.new(url, ssl_verify_peer: true, ssl_ca_file: data_path('127.0.0.1.cert.crt'))

    assert_equal 200, connection.request(method: :get, path: '/content-length/100').status
  end

  def test_verify_peer_and_hostname_with_a_ca_file_succeeds
    connection = Excon.new(url, ssl_verify_peer: true, ssl_ca_file: data_path('127.0.0.1.cert.crt'),
                                ssl_verify_hostname: true)

    assert_equal 200, connection.request(method: :get, path: '/content-length/100').status
  end

  def test_verify_peer_with_a_cert_store_succeeds
    ssl_cert_store = OpenSSL::X509::Store.new
    ssl_cert_store.add_cert(OpenSSL::X509::Certificate.new(File.read(data_path('127.0.0.1.cert.crt'))))
    connection = Excon.new(url, ssl_verify_peer: true, ssl_cert_store: ssl_cert_store)

    assert_equal 200, connection.request(method: :get, path: '/content-length/100').status
  end
end

# tests/rackups/ssl_mismatched_cn.ru serves a certificate for 'excon' on
# 127.0.0.1:9443.
class BasicSslMismatchedCnTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'ssl_mismatched_cn.ru'

  def test_verify_peer_host_checks_the_certificate_against_that_name
    connection = Excon.new('https://127.0.0.1:9443', ssl_verify_peer: true,
                                                     ssl_ca_file: data_path('excon.cert.crt'),
                                                     ssl_verify_peer_host: 'excon')

    assert_equal 200, connection.request(method: :get, path: '/content-length/100').status
  end
end

# tests/rackups/ssl_sni_verify_host.ru serves the 'excon' certificate on
# 127.0.0.1:9443 only to clients that send 'excon' as the SNI name.
class BasicSslSniTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'ssl_sni_verify_host.ru'

  def test_verify_peer_host_is_sent_as_the_sni_name
    # jruby-openssl servers never call servername_cb, so the vhost cert is
    # never served (and Java clients don't send SNI for dotless names)
    skip 'jruby-openssl servers ignore SNI' if RUBY_PLATFORM == 'java'

    connection = Excon.new('https://127.0.0.1:9443', ssl_verify_peer: true,
                                                     ssl_ca_file: data_path('excon.cert.crt'),
                                                     ssl_verify_peer_host: 'excon')

    assert_equal 200, connection.request(method: :get, path: '/content-length/100').status
  end
end

# tests/rackups/ssl_verify_peer.ru serves basic.ru over HTTPS on port 8443,
# and only to clients presenting the excon certificate.
module SslClientCertificateTests
  def test_request_without_a_client_certificate_fails
    connection = Excon::Connection.new(host: '127.0.0.1', hostname: '127.0.0.1', nonblock: false,
                                       port: 8443, scheme: 'https', ssl_verify_peer: false)

    assert_raises(Excon::Error::Socket) do
      connection.request(method: :get, path: '/content-length/100')
    end
  end
end

class BasicSslClientCertFileTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests
  include SslClientCertificateTests

  test_server :webrick, 'ssl_verify_peer.ru'

  def url
    'https://127.0.0.1:8443'
  end

  def client_options
    { client_key: data_path('excon.cert.key'), client_cert: data_path('excon.cert.crt') }
  end
end

class BasicSslClientCertDataTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'ssl_verify_peer.ru'

  def url
    'https://127.0.0.1:8443'
  end

  def client_options
    {
      client_key_data: File.read(data_path('excon.cert.key')),
      client_cert_data: File.read(data_path('excon.cert.crt'))
    }
  end
end

# :private_key and :certificate are the older names for :client_key_data
# and :client_cert_data.
class BasicSslPrivateKeyAndCertificateTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'ssl_verify_peer.ru'

  def url
    'https://127.0.0.1:8443'
  end

  def client_options
    {
      private_key: File.read(data_path('excon.cert.key')),
      certificate: File.read(data_path('excon.cert.crt'))
    }
  end
end

# tests/rackups/ssl_verify_peer_with_chain.ru is ssl_verify_peer.ru, but
# only trusts the excon certificate, which signed excon_intermediate, which
# signed excon_client. So the client has to send the intermediate too.
class BasicSslClientChainFileTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests
  include SslClientCertificateTests

  test_server :webrick, 'ssl_verify_peer_with_chain.ru'

  def url
    'https://127.0.0.1:8443'
  end

  def client_options
    {
      client_key: data_path('excon_client.cert.key'),
      client_cert: data_path('excon_client.cert.crt'),
      client_chain: data_path('excon_intermediate.cert.crt')
    }
  end
end

class BasicSslClientChainDataTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests

  test_server :webrick, 'ssl_verify_peer_with_chain.ru'

  def url
    'https://127.0.0.1:8443'
  end

  def client_options
    {
      client_key_data: File.read(data_path('excon_client.cert.key')),
      client_cert_data: File.read(data_path('excon_client.cert.crt')),
      client_chain_data: File.read(data_path('excon_intermediate.cert.crt'))
    }
  end
end

# basic.ru served by puma on a unix socket. Leaves out ServerDetails:
# puma sends no Date or Server header, and a unix socket has no remote IP.
class BasicUnixSocketTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include BasicClientTests::Helpers
  include BasicClientTests::MethodAndPathDefaults
  include BasicClientTests::Responses
  include BasicClientTests::RequestBodies

  SOCKET = File.join(Dir.tmpdir, 'excon-basic-test.sock')

  test_server :puma, 'basic.ru', bind: "unix://#{SOCKET}"

  def url
    'unix:/'
  end

  def client_options
    { socket: SOCKET }
  end

  def explicit_connection
    Excon::Connection.new(socket: SOCKET, nonblock: false, scheme: 'unix', ssl_verify_peer: false)
  end

  def test_connection_with_explicit_options_gets_a_response
    response = explicit_connection.request(method: :get, path: '/content-length/100')

    assert_equal 200, response[:status]
  end

  # /headers returns the request's HTTP_* rack variables as JSON
  def test_sends_an_empty_host_header
    response = explicit_connection.request(method: :get, path: '/headers')

    assert_equal '', JSON.parse(response.body)['HTTP_HOST']
  end
end

# :reuseaddr lets another socket bind the connection's local address and
# port while it's still open. basic.ru listens on every address here, so
# that socket can connect from the same port to a different address.
class BasicReusableLocalPortTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'basic.ru', bind: 'tcp://0.0.0.0:9292'

  # A socket with address and port reuse enabled.
  class ReusableSocket < Socket
    def initialize
      super(AF_INET, SOCK_STREAM, 0)
      setsockopt(SOL_SOCKET, SO_REUSEADDR, true)
      setsockopt(SOL_SOCKET, SO_REUSEPORT, true) if defined?(SO_REUSEPORT)
    end

    def bind(address, port)
      super(Socket.pack_sockaddr_in(port, address))
    end

    def connect(address, port)
      super(Socket.pack_sockaddr_in(port, address))
    end

    def http_get(path)
      print "GET #{path} HTTP/1.0\r\n\r\n"
      read.split("\r\n\r\n", 2)[1]
    end
  end

  def persistent_connection
    Excon.new('http://127.0.0.1:9292/echo', reuseaddr: true, persistent: true)
  end

  def test_response_has_a_local_port
    response = persistent_connection.get

    assert_match(/\A\d{4,5}\z/, response.local_port.to_s)
  end

  def test_local_port_can_be_bound_again_while_the_connection_is_open
    @connection = persistent_connection
    response = @connection.get
    # a different address avoids a duplicate {protocol, local address and
    # port, remote address and port}
    other_ip = other_ipv4_address(response.local_address)
    skip 'needs a second IPv4 address (e.g. not in a container without networking)' unless other_ip

    body = get_from(response.local_address, response.local_port, other_ip, '/content-length/10')

    assert_equal 'x' * 10, body
  end

  def teardown
    @connection&.reset
    super
  end

  private

  def other_ipv4_address(address)
    Socket.ip_address_list.select(&:ipv4?).map(&:ip_address).find { |ip| ip != address }
  end

  # GETs path from basic.ru at remote_address, via a ReusableSocket bound to
  # local_address and local_port.
  def get_from(local_address, local_port, remote_address, path)
    socket = ReusableSocket.new
    socket.bind(local_address, local_port)
    socket.connect(remote_address, 9292)
    socket.http_get(path)
  ensure
    socket&.close
  end
end
