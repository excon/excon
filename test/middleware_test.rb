# frozen_string_literal: true

require_relative 'test_helper'

class MiddlewareTest < Minitest::Test
  include TestServer

  test_server :webrick, 'basic.ru'

  # Passes every call through, but doesn't define .valid_parameter_keys.
  class MiddlewareWithoutValidKeys
    def initialize(stack)
      @stack = stack
    end

    def error_call(datum)
      @stack.error_call(datum)
    end

    def request_call(datum)
      @stack.request_call(datum)
    end

    def response_call(datum)
      @stack.response_call(datum)
    end
  end

  def request_with_middleware
    Excon.get(
      'http://127.0.0.1:9292/content-length/100',
      middlewares: Excon.defaults[:middlewares] + [MiddlewareWithoutValidKeys]
    )
  end

  def test_succeeds_without_defining_valid_parameter_keys
    response = silence_warnings { request_with_middleware }

    assert_equal 200, response.status
    assert_equal 'x' * 100, response.body
  end

  def test_warns_without_defining_valid_parameter_keys
    error = assert_raises(Excon::Error::Warning) { request_with_middleware }
    assert_includes error.message, "#{MiddlewareWithoutValidKeys} does not define #valid_parameter_keys"
  end
end
