# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/basic_client_tests'
require 'open3'
require 'rbconfig'

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
