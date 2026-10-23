# frozen_string_literal: true

require_relative 'test_helper'

# Excon checks connection and request parameters against the keys its
# middlewares declare valid, and warns (raising Excon::Error::Warning, since
# the test helper sets raise_on_warnings) about any others. Validation runs
# before a request is sent, so only the tests that expect a request to
# succeed need a stub.
class ValidationTest < Minitest::Test
  # A middleware that makes :foo a valid key.
  class FooMiddleware < Excon::Middleware::Base
    def self.valid_parameter_keys
      [:foo]
    end
  end

  def teardown
    Excon.stubs.clear
  end

  # With default middleware

  def test_connection_new_warns_on_invalid_keys
    assert_parameter_warning('connection', :foo) do
      Excon.new('http://foo', foo: :bar)
    end
  end

  def test_request_warns_on_invalid_keys
    connection = Excon.new('http://foo')

    assert_parameter_warning('request', :foo) do
      connection.request(foo: :bar)
    end
  end

  # With custom middleware at instantiation

  def test_connection_new_accepts_keys_valid_for_its_middleware
    connection = Excon.new('http://foo', foo: :bar, middlewares: foo_stack)

    assert_equal :bar, connection.data[:foo]
  end

  def test_connection_new_warns_on_keys_invalid_for_its_middleware
    assert_parameter_warning('connection', :bar) do
      Excon.new('http://foo', bar: :baz, middlewares: foo_stack)
    end
  end

  def test_request_accepts_keys_valid_for_the_connection_middleware
    Excon.stub({}, {})
    connection = Excon.new('http://foo', middlewares: foo_stack, mock: true)

    assert_equal 200, connection.request(foo: :bar).status
  end

  def test_request_warns_on_keys_invalid_for_the_connection_middleware
    connection = Excon.new('http://foo', middlewares: foo_stack)

    assert_parameter_warning('request', :bar) do
      connection.request(bar: :baz)
    end
  end

  # With custom middleware at request time

  def test_request_accepts_keys_valid_for_the_request_middleware
    Excon.stub({}, {})
    connection = Excon.new('http://foo', mock: true)

    assert_equal 200, connection.request(foo: :bar, middlewares: foo_stack).status
  end

  def test_request_warns_on_keys_invalid_for_the_request_middleware
    connection = Excon.new('http://foo')

    assert_parameter_warning('request', :bar) do
      connection.request(bar: :baz, middlewares: foo_stack)
    end
  end

  # Connection parameters are revalidated against middleware passed to a
  # request, so :foo stops being valid once FooMiddleware is dropped.
  def test_request_warns_on_connection_keys_invalid_for_the_request_middleware
    connection = Excon.new('http://foo', foo: :bar, middlewares: foo_stack)

    assert_parameter_warning('connection', :foo) do
      connection.request(middlewares: Excon.defaults[:middlewares])
    end
  end

  private

  def foo_stack
    Excon.defaults[:middlewares] + [FooMiddleware]
  end

  def assert_parameter_warning(validation, key, &)
    error = assert_raises(Excon::Error::Warning, &)

    assert_equal "Invalid Excon #{validation} keys: #{key.inspect}", error.message
  end
end
