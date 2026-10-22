# frozen_string_literal: true

require_relative 'test_helper'

# Connection#batch_requests sends requests in pipelined batches of at most
# `limit` requests each.
#
# The server's /echo/request_count returns how many requests it has received
# on the current TCP connection, so '1' means the request opened a new
# connection. A non-persistent connection opens one connection per batch; a
# persistent one reuses a single connection for every batch.
class BatchRequestsTest < Minitest::Test
  include TestServer

  test_server :exec, 'good_ipv4.rb'

  def test_batches_of_two
    assert_equal %w[1 2 1 2], request_counts(persistent: false, limit: 2)
  end

  def test_persistent_batches_of_two
    assert_equal %w[1 2 3 4], request_counts(persistent: true, limit: 2)
  end

  def test_batches_of_three
    assert_equal %w[1 2 3 1], request_counts(persistent: false, limit: 3)
  end

  def test_persistent_batches_of_three
    assert_equal %w[1 2 3 4], request_counts(persistent: true, limit: 3)
  end

  def test_batch_of_four
    assert_equal %w[1 2 3 4], request_counts(persistent: false, limit: 4)
  end

  def test_persistent_batch_of_four
    assert_equal %w[1 2 3 4], request_counts(persistent: true, limit: 4)
  end

  def test_limit_above_the_request_count
    assert_equal %w[1 2 3 4], request_counts(persistent: false, limit: 8)
  end

  def test_persistent_limit_above_the_request_count
    assert_equal %w[1 2 3 4], request_counts(persistent: true, limit: 8)
  end

  private

  # Sends four requests in batches of `limit`, returning each request's count.
  def request_counts(persistent:, limit:)
    connection = Excon.new('http://127.0.0.1:9292', persistent: persistent)
    requests = Array.new(4) { { method: :get, path: '/echo/request_count' } }
    connection.batch_requests(requests, limit).map(&:body)
  end
end
