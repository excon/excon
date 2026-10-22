# frozen_string_literal: true

require_relative 'test_helper'

# Whether a connection is kept open between requests (:persistent), both as a
# connection default and overridden per request.
#
# The server's /echo/request_count returns how many requests it has received
# on the current TCP connection, so '1' means the request opened a new
# connection and anything higher means it reused one.
#
# Included below once per server, to cover both IPv4 and IPv6.
module PersistentConnectionTests
  def test_persistent_connection_reuses_the_connection
    connection = Excon.new(url, persistent: true)

    assert_equal '1', request_count(connection)
    assert_equal '2', request_count(connection) # same connection
  end

  def test_persistent_false_on_a_request_closes_the_connection_after_it
    connection = Excon.new(url, persistent: true)
    request_count(connection)

    assert_equal '2', request_count(connection, persistent: false) # same connection, then closed
    assert_equal '1', request_count(connection) # new connection
    assert_equal '2', request_count(connection) # reused again
  end

  def test_non_persistent_connection_opens_a_connection_per_request
    connection = Excon.new(url, persistent: false)

    assert_equal '1', request_count(connection)
    assert_equal '1', request_count(connection) # new connection
  end

  def test_persistent_true_on_a_request_keeps_the_connection_open_after_it
    connection = Excon.new(url, persistent: false)

    assert_equal '1', request_count(connection, persistent: true)
    assert_equal '2', request_count(connection, persistent: true) # same connection
    assert_equal '3', request_count(connection) # same connection, then closed
    assert_equal '1', request_count(connection) # new connection
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

  # Why these tests can't run here, or nil if they can.
  def self.unsupported_reason
    return 'good_ipv6.rb does not listen on JRuby' if RUBY_PLATFORM == 'java'

    TCPServer.new('::1', 0).close
    nil
  rescue SystemCallError => e
    "IPv6 loopback (::1) is unavailable: #{e.message}"
  end

  UNSUPPORTED_REASON = unsupported_reason

  # Starting a server that can't listen would fail the whole class, so only
  # declare it where it can run, and skip the tests everywhere else.
  test_server :exec, 'good_ipv6.rb' unless UNSUPPORTED_REASON

  def setup
    skip UNSUPPORTED_REASON if UNSUPPORTED_REASON
    super
  end

  def url
    'http://[::1]:9293'
  end
end
