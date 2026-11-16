# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/fake_socks5_server'
require_relative 'support/recording_scheduler'

# Requests made from a non-blocking fiber, where Ruby hands socket waits to
# the thread's fiber scheduler. Waiting with IO.select calls its io_select
# hook, which Async runs on a new thread and schedulers without it run as a
# blocking select; excon should wait through io_wait instead.
#
# timeout.ru answers /no-timeout straight away and sleeps 0.1 seconds before
# answering /timeout, so reading its response has to wait.
class FiberSchedulerTest < Minitest::Test
  include TestServer

  test_server :webrick, 'timeout.ru'

  def setup
    super
    @scheduler = RecordingScheduler.new
  end

  def test_read_waits_through_io_wait
    response = RecordingScheduler.run(@scheduler) { connection.request(path: '/timeout') }

    assert_equal 200, response.status
    assert_includes @scheduler.calls, :io_wait
    refute_includes @scheduler.calls, :io_select
  end

  def test_read_timeout_raises_timeout
    # like Async's, the scheduler's io_wait returns false when the timeout is
    # reached, which IO#wait_readable returns as nil
    conn = connection(read_timeout: 0.001)

    error = assert_raises(Excon::Error::Timeout) do
      RecordingScheduler.run(@scheduler) { conn.request(path: '/timeout') }
    end
    assert_equal 'read timeout reached', error.message
  end

  def test_socks5_handshake_waits_through_io_wait
    proxy = FakeSOCKS5Server.new.start
    conn = connection(socks5_proxy: "127.0.0.1:#{proxy.port}")

    response = RecordingScheduler.run(@scheduler) { conn.request(path: '/no-timeout') }

    assert_equal 200, response.status
    refute_includes @scheduler.calls, :io_select
  ensure
    proxy&.stop
  end

  def test_socks5_handshake_without_read_timeout_waits_through_io_wait
    # without a deadline, the handshake waits only when a read would block
    proxy = FakeSOCKS5Server.new.start
    conn = connection(socks5_proxy: "127.0.0.1:#{proxy.port}", read_timeout: nil)

    response = RecordingScheduler.run(@scheduler) { conn.request(path: '/no-timeout') }

    assert_equal 200, response.status
    refute_includes @scheduler.calls, :io_select
  ensure
    proxy&.stop
  end

  private

  def connection(**)
    Excon.new('http://127.0.0.1:9292', **)
  end
end
