# frozen_string_literal: true

require_relative 'test_helper'

# timeout.ru answers /no-timeout straight away and sleeps 0.1 seconds before
# answering /timeout. :timeout is the deadline for the whole request;
# :read_timeout bounds each read.
class TimeoutTest < Minitest::Test
  include TestServer

  test_server :webrick, 'timeout.ru'

  # Blocking connections

  def test_blocking_without_timeout_does_not_error
    assert_equal 200, connection(nonblock: false, timeout: nil).request(path: '/no-timeout').status
  end

  def test_blocking_with_untriggered_timeout_does_not_error
    assert_equal 200, connection(nonblock: false, timeout: 1).request(path: '/no-timeout').status
  end

  def test_blocking_with_triggered_timeout_raises_read_timeout
    # a short read timeout keeps the test fast; it fires before the request
    # timeout is checked
    conn = connection(nonblock: false, timeout: 0.001, read_timeout: 0.005)

    error = assert_raises(Excon::Error::Timeout) { conn.request(path: '/timeout') }
    assert_equal 'read timeout reached', error.message
  end

  # Non-blocking connections

  def test_nonblock_without_timeout_does_not_error
    assert_equal 200, connection(nonblock: true, timeout: nil).request(path: '/no-timeout').status
  end

  def test_nonblock_with_untriggered_timeout_does_not_error
    assert_equal 200, connection(nonblock: true, timeout: 1).request(path: '/no-timeout').status
  end

  def test_nonblock_with_triggered_timeout_raises_request_timeout
    conn = connection(nonblock: true, timeout: 0.001)

    error = assert_raises(Excon::Error::Timeout) { conn.request(path: '/timeout') }
    assert_equal 'request timeout reached', error.message
  end

  def test_nonblock_with_triggered_read_timeout_raises_read_timeout
    conn = connection(nonblock: true, timeout: 5, read_timeout: 0.001)

    error = assert_raises(Excon::Error::Timeout) { conn.request(path: '/timeout') }
    assert_equal 'read timeout reached', error.message
  end

  private

  def connection(nonblock:, timeout:, read_timeout: 60)
    Excon::Connection.new(
      host: '127.0.0.1',
      hostname: '127.0.0.1',
      nonblock: nonblock,
      port: 9292,
      scheme: 'http',
      timeout: timeout,
      read_timeout: read_timeout
    )
  end
end
