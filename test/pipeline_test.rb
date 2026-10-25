# frozen_string_literal: true

require_relative 'test_helper'

# Connection#requests sends its requests pipelined on one connection. Each
# test makes two calls of two requests each.
#
# The server's /echo/request_count returns how many requests it has received
# on the current TCP connection, so '1' means the request opened a new
# connection and anything higher means it reused one.
class PipelineTest < Minitest::Test
  include TestServer

  test_server :exec, 'good_ipv4.rb'

  def test_persistent_connection_is_reused_across_calls
    first, second, third, fourth = request_counts(persistent: true)

    assert_equal '1', first  # first call: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # second call: still the same connection
    assert_equal '4', fourth # same connection
  end

  def test_non_persistent_connection_is_reused_only_within_a_call
    first, second, third, fourth = request_counts(persistent: false)

    assert_equal '1', first  # first call: new connection
    assert_equal '2', second # same connection
    assert_equal '1', third  # second call: new connection
    assert_equal '2', fourth # same connection
  end

  private

  def request_counts(persistent:)
    connection = Excon.new('http://127.0.0.1:9292', persistent: persistent)
    pair = [{ method: :get, path: '/echo/request_count' }] * 2

    Array.new(2) { connection.requests(pair).map(&:body) }.flatten
  end
end
