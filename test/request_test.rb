# frozen_string_literal: true

require_relative 'test_helper'

# Run against both good_ipv4.rb and good_ipv6.rb. The server's
# /echo/request_count counts requests per connection, so it shows whether a
# connection was reused.
module PersistentConnectionTests
  def test_persistent_true_reuses_the_connection
    connection = Excon.new(url, persistent: true)
    assert_equal %w[1 2], [request_count(connection), request_count(connection)]

    # persistent: false on a request closes the connection after it
    assert_equal %w[3 1 2], [
      request_count(connection, persistent: false),
      request_count(connection),
      request_count(connection)
    ]
  end

  def test_persistent_false_opens_a_connection_per_request
    connection = Excon.new(url, persistent: false)
    assert_equal %w[1 1], [request_count(connection), request_count(connection)]

    # persistent: true on a request keeps the connection open after it
    assert_equal %w[1 2 3 1], [
      request_count(connection, persistent: true),
      request_count(connection, persistent: true),
      request_count(connection),
      request_count(connection)
    ]
  end

  private

  def request_count(connection, **)
    connection.request(method: :get, path: '/echo/request_count', **).body
  end
end

class RequestIPv4Test < Minitest::Test
  include TestServer
  include PersistentConnectionTests

  test_server :exec, 'good_ipv4.rb'

  def url
    'http://127.0.0.1:9292'
  end
end

class RequestIPv6Test < Minitest::Test
  include TestServer
  include PersistentConnectionTests

  UNSUPPORTED =
    if RUBY_PLATFORM == 'java'
      'good_ipv6.rb does not listen on JRuby'
    else
      begin
        TCPServer.new('::1', 0).close
        nil
      rescue SystemCallError => e
        "IPv6 loopback (::1) is unavailable: #{e.message}"
      end
    end

  # Only start the server where it can run; otherwise every test skips.
  test_server :exec, 'good_ipv6.rb' unless UNSUPPORTED

  def setup
    skip UNSUPPORTED if UNSUPPORTED
    super
  end

  def url
    'http://[::1]:9293'
  end
end
