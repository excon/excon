# frozen_string_literal: true

require_relative 'test_helper'

# A request that is left partway, by an exception the connection's rescue
# doesn't see (Timeout.timeout, Thread#raise, Thread#kill, Interrupt), can
# leave its response unread on the socket. If that socket were used again,
# the next request would read the earlier request's response instead of its
# own.
#
# InterruptResponse is put before the default middlewares, so it raises before
# ResponseParser reads anything, leaving the whole response on the socket. The
# server's /foo responds 'foo' and /bar responds 'bar', so a '/bar' request
# reading 'foo' means it reused the dirty socket.
class InterruptedRequestTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'basic.ru'

  # An Exception, not a StandardError, like the exceptions Timeout.timeout
  # and Thread#raise use to interrupt a thread.
  class SimulatedInterrupt < Exception; end # rubocop:disable Lint/InheritException

  class InterruptResponse < Excon::Middleware::Base
    def response_call(_datum)
      raise SimulatedInterrupt
    end
  end

  def test_persistent_connection_does_not_reuse_interrupted_socket
    connection = Excon.new('http://127.0.0.1:9292', persistent: true)

    interrupted { connection.request(path: '/foo', middlewares: interrupting_middlewares) }

    assert_equal 'bar', connection.request(path: '/bar').body
  end

  def test_non_persistent_connection_does_not_reuse_interrupted_socket
    connection = Excon.new('http://127.0.0.1:9292', persistent: false)

    interrupted { connection.request(path: '/foo', middlewares: interrupting_middlewares) }

    assert_equal 'bar', connection.request(path: '/bar').body
  end

  def test_request_from_another_thread_does_not_clear_interrupted_socket
    connection = Excon.new('http://127.0.0.1:9292', persistent: true)

    interrupted { connection.request(path: '/foo', middlewares: interrupting_middlewares) }
    # with thread_safe_sockets this thread uses its own socket, not ours
    Thread.new { connection.request(path: '/foo') }.join

    assert_equal 'bar', connection.request(path: '/bar').body
  end

  def test_pipelined_requests_do_not_reuse_interrupted_socket
    connection = Excon.new('http://127.0.0.1:9292', persistent: true)

    interrupted { connection.requests([{ path: '/foo', middlewares: interrupting_middlewares }]) }

    assert_equal 'bar', connection.request(path: '/bar').body
  end

  private

  def interrupting_middlewares
    [InterruptResponse] + Excon.defaults[:middlewares]
  end

  def interrupted(&block)
    assert_raises(SimulatedInterrupt, &block)
  end
end
