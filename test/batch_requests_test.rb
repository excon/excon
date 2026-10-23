# frozen_string_literal: true

require_relative 'test_helper'

# Connection#batch_requests sends requests in pipelined batches of at most
# `limit` requests each. Each test sends four requests.
#
# The server's /echo/request_count returns how many requests it has received
# on the current TCP connection, so '1' means the request opened a new
# connection and anything higher means it reused one.
class BatchRequestsTest < Minitest::Test
  include TestServer

  test_server :exec, 'good_ipv4.rb'

  # Non-persistent: each batch opens a connection, closed after the batch.

  def test_batches_of_two_open_a_connection_per_batch
    first, second, third, fourth = request_counts(persistent: false, limit: 2)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '1', third  # second batch: new connection
    assert_equal '2', fourth # same connection
  end

  def test_batches_of_three_open_a_connection_per_batch
    first, second, third, fourth = request_counts(persistent: false, limit: 3)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '1', fourth # second batch: new connection
  end

  def test_batch_of_four_uses_one_connection
    first, second, third, fourth = request_counts(persistent: false, limit: 4)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  def test_limit_above_the_request_count_sends_one_batch
    first, second, third, fourth = request_counts(persistent: false, limit: 8)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  # Persistent: every batch reuses the one connection.

  def test_persistent_batches_of_two_share_a_connection
    first, second, third, fourth = request_counts(persistent: true, limit: 2)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # second batch: still the same connection
    assert_equal '4', fourth # same connection
  end

  def test_persistent_batches_of_three_share_a_connection
    first, second, third, fourth = request_counts(persistent: true, limit: 3)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # second batch: still the same connection
  end

  def test_persistent_batch_of_four_uses_one_connection
    first, second, third, fourth = request_counts(persistent: true, limit: 4)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  def test_persistent_limit_above_the_request_count_sends_one_batch
    first, second, third, fourth = request_counts(persistent: true, limit: 8)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  private

  # Sends four requests in batches of `limit`, returning each one's count.
  def request_counts(persistent:, limit:)
    connection = Excon.new('http://127.0.0.1:9292', persistent: persistent)
    requests = Array.new(4) { { method: :get, path: '/echo/request_count' } }
    connection.batch_requests(requests, limit).map(&:body)
  end
end
