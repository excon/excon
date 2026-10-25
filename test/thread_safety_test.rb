# frozen_string_literal: true

require_relative 'test_helper'

class ThreadSafeSocketsOptionTest < Minitest::Test
  def test_thread_safe_sockets_defaults_to_true
    connection = Excon.new('http://foo.com')

    assert_equal true, connection.data[:thread_safe_sockets]
  end

  def test_thread_safe_sockets_can_be_set_false
    connection = Excon.new('http://foo.com', thread_safe_sockets: false)

    assert_equal false, connection.data[:thread_safe_sockets]
  end
end

# thread_safety.ru answers GET /id/<id>/wait/<seconds> with <id> after
# sleeping <seconds>.
class ThreadSafetyTest < Minitest::Test
  include TestServer

  test_server :webrick, 'thread_safety.ru'

  def test_concurrent_requests_on_one_connection_each_get_their_own_response
    connection = Excon.new('http://127.0.0.1:9292')

    # the slower request is in flight before the faster one starts, so a shared
    # socket would be reused (rather than both threads opening their own) and
    # the faster one finishes while the slower one is still waiting
    long_thread = Thread.new { connection.request(method: 'GET', path: '/id/1/wait/2').body }
    sleep 0.5
    short_thread = Thread.new { connection.request(method: 'GET', path: '/id/2/wait/1').body }

    assert_equal '1', long_thread.value
    assert_equal '2', short_thread.value
  end
end
