# frozen_string_literal: true

require_relative 'test_helper'

# Connection#requests pipelines its requests on one connection: it sends them
# all, then reads all the responses. Connection#batch_requests slices a list
# into batches of at most `limit` requests and calls #requests once per batch.
# Each test sends four requests.
#
# The server's /echo/request_count returns how many requests it has received
# on the current TCP connection, so '1' means the request opened a new
# connection and anything higher means it reused one.
class PipeliningTest < Minitest::Test
  include TestServer

  test_server :exec, 'good_ipv4.rb'

  # requests: each test makes two calls of two requests each.

  def test_requests_reuses_a_persistent_connection_across_calls
    first, second, third, fourth = requests_counts(persistent: true)

    assert_equal '1', first  # first call: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # second call: still the same connection
    assert_equal '4', fourth # same connection
  end

  def test_requests_reuses_a_non_persistent_connection_only_within_a_call
    first, second, third, fourth = requests_counts(persistent: false)

    assert_equal '1', first  # first call: new connection
    assert_equal '2', second # same connection
    assert_equal '1', third  # second call: new connection
    assert_equal '2', fourth # same connection
  end

  # batch_requests: on a non-persistent connection each batch opens a new
  # connection, so a '1' marks where a batch starts.

  def test_batch_requests_in_batches_of_two
    first, second, third, fourth = batch_requests_counts(persistent: false, limit: 2)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '1', third  # second batch: new connection
    assert_equal '2', fourth # same connection
  end

  def test_batch_requests_in_batches_of_three
    first, second, third, fourth = batch_requests_counts(persistent: false, limit: 3)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '1', fourth # second batch: new connection
  end

  def test_batch_requests_with_limit_equal_to_the_request_count_sends_one_batch
    first, second, third, fourth = batch_requests_counts(persistent: false, limit: 4)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  def test_batch_requests_with_limit_above_the_request_count_sends_one_batch
    first, second, third, fourth = batch_requests_counts(persistent: false, limit: 8)

    assert_equal '1', first  # only batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # same connection
    assert_equal '4', fourth # same connection
  end

  def test_batch_requests_shares_a_persistent_connection_across_batches
    first, second, third, fourth = batch_requests_counts(persistent: true, limit: 2)

    assert_equal '1', first  # first batch: new connection
    assert_equal '2', second # same connection
    assert_equal '3', third  # second batch: still the same connection
    assert_equal '4', fourth # same connection
  end

  private

  def request_count_requests(count)
    Array.new(count) { { method: :get, path: '/echo/request_count' } }
  end

  # Sends two requests calls of two requests each, returning each one's count.
  def requests_counts(persistent:)
    connection = Excon.new('http://127.0.0.1:9292', persistent: persistent)

    Array.new(2) { connection.requests(request_count_requests(2)).map(&:body) }.flatten
  end

  # Sends four requests in batches of `limit`, returning each one's count.
  def batch_requests_counts(persistent:, limit:)
    connection = Excon.new('http://127.0.0.1:9292', persistent: persistent)

    connection.batch_requests(request_count_requests(4), limit).map(&:body)
  end
end
