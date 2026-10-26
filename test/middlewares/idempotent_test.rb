# frozen_string_literal: true

require_relative '../test_helper'

# The Idempotent middleware retries a request marked :idempotent when it
# fails with one of :retry_errors (by default, socket errors among others).
# :retry_limit (default 4) counts every attempt, including the first, so a
# request that fails :retry_limit times raises the last error.
#
# Each test stubs a request that fails a given number of times and then
# succeeds, and checks the outcome and how many attempts were made.
module IdempotentTestHelpers
  def setup
    @connection = Excon.new('http://127.0.0.1:9292', mock: true)
    @attempts = 0
  end

  def teardown
    Excon.stubs.clear
  end

  private

  # Stubs GET to fail the first `failures` times, raising a socket error
  # unless a block raising something else is given, and then succeed.
  def stub_failures(failures, &raise_error)
    raise_error ||= -> { raise Excon::Error::Socket, Exception.new('Mock Error') }
    Excon.stub({ method: :get }) do |params|
      @attempts += 1
      raise_error.call if @attempts <= failures

      { body: params[:body], headers: params[:headers], status: 200 }
    end
  end
end

# :retry_limit given per request, or left at its default.
class IdempotentRetryLimitTest < Minitest::Test
  include IdempotentTestHelpers

  def test_non_idempotent_request_is_not_retried
    stub_failures(3)

    assert_raises(Excon::Error::Socket) do
      @connection.request(method: :get, path: '/some-path')
    end
    assert_equal 1, @attempts
  end

  def test_succeeds_within_default_retry_limit
    stub_failures(3)

    response = @connection.request(method: :get, idempotent: true, path: '/some-path')

    assert_equal 200, response.status
    assert_equal 4, @attempts
  end

  def test_raises_after_default_retry_limit
    stub_failures(5)

    assert_raises(Excon::Error::Socket) do
      @connection.request(method: :get, idempotent: true, path: '/some-path')
    end
    assert_equal 4, @attempts
  end

  def test_succeeds_within_lowered_retry_limit
    stub_failures(1)

    response = @connection.request(method: :get, idempotent: true, path: '/some-path', retry_limit: 2)

    assert_equal 200, response.status
    assert_equal 2, @attempts
  end

  def test_raises_after_lowered_retry_limit
    stub_failures(3)

    assert_raises(Excon::Error::Socket) do
      @connection.request(method: :get, idempotent: true, path: '/some-path', retry_limit: 2)
    end
    assert_equal 2, @attempts
  end

  def test_succeeds_within_raised_retry_limit
    stub_failures(5)

    response = @connection.request(method: :get, idempotent: true, path: '/some-path', retry_limit: 8)

    assert_equal 200, response.status
    assert_equal 6, @attempts
  end

  def test_raises_after_raised_retry_limit
    stub_failures(9)

    assert_raises(Excon::Error::Socket) do
      @connection.request(method: :get, idempotent: true, path: '/some-path', retry_limit: 8)
    end
    assert_equal 8, @attempts
  end
end

# :retry_limit and :retry_interval set on the connection.
class IdempotentConnectionDefaultsTest < Minitest::Test
  include IdempotentTestHelpers

  def test_succeeds_within_retry_limit_set_on_connection
    stub_failures(5)
    connection = Excon.new('http://127.0.0.1:9292', mock: true, retry_limit: 6)

    response = connection.request(method: :get, idempotent: true, path: '/some-path')

    assert_equal 200, response.status
    assert_equal 6, @attempts
  end

  def test_succeeds_within_retry_limit_and_interval_set_on_connection
    stub_failures(2)
    # A short :retry_interval keeps the test fast.
    connection = Excon.new('http://127.0.0.1:9292', mock: true, retry_limit: 3, retry_interval: 0.1)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = connection.request(method: :get, idempotent: true, path: '/some-path')
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_equal 200, response.status
    assert_equal 3, @attempts
    assert_operator elapsed, :>=, 0.2 # slept before each of the 2 retries
  end

  def test_raises_after_retry_limit_and_interval_set_on_connection
    stub_failures(2)
    connection = Excon.new('http://127.0.0.1:9292', mock: true, retry_limit: 2, retry_interval: 0.1)

    assert_raises(Excon::Error::Socket) do
      connection.request(method: :get, idempotent: true, path: '/some-path')
    end
    assert_equal 2, @attempts
  end
end

# Which errors are retried.
class IdempotentRetryErrorsTest < Minitest::Test
  include IdempotentTestHelpers

  def test_retries_custom_retry_errors
    stub_failures(3) { raise 'oops' }

    response = @connection.request(method: :get, idempotent: true, retry_errors: [RuntimeError], path: '/some-path')

    assert_equal 200, response.status
    assert_equal 4, @attempts
  end

  def test_raises_custom_retry_error_after_retry_limit
    stub_failures(5) { raise 'oops' }

    error = assert_raises(RuntimeError) do
      @connection.request(method: :get, idempotent: true, retry_errors: [RuntimeError], path: '/some-path')
    end
    assert_equal 'oops', error.message
    assert_equal 4, @attempts
  end

  def test_custom_retry_errors_replace_the_defaults
    stub_failures(1)

    # Socket errors are retried by default, but not once :retry_errors is set.
    assert_raises(Excon::Error::Socket) do
      @connection.request(method: :get, idempotent: true, retry_errors: [RuntimeError], path: '/some-path')
    end
    assert_equal 1, @attempts
  end
end

# Request and response blocks are rewound before a retry.
class IdempotentRewindTest < Minitest::Test
  include IdempotentTestHelpers

  # A request or response block that records whether it was rewound.
  class RewindableBlock
    attr_reader :rewound

    def initialize
      @rewound = false
    end

    def call(_chunk); end

    def rewind
      @rewound = true
    end
  end

  def test_rewinds_request_block_before_retrying
    stub_failures(1)
    request_block = RewindableBlock.new

    @connection.request(
      method: :get, idempotent: true, path: '/some-path',
      request_block: request_block, retry_limit: 2
    )

    assert request_block.rewound
  end

  def test_rewinds_response_block_before_retrying
    stub_failures(1)
    response_block = RewindableBlock.new

    @connection.request(
      method: :get, idempotent: true, path: '/some-path',
      response_block: response_block, retry_limit: 2
    )

    assert response_block.rewound
  end
end

# Retry options only take effect on :idempotent requests, so a request that
# sets them without :idempotent warns (raising Excon::Error::Warning, since
# the test helper sets raise_on_warnings).
class IdempotentRetryWarningTest < Minitest::Test
  include IdempotentTestHelpers

  def test_warns_on_retry_keys_without_idempotent
    error = assert_raises(Excon::Error::Warning) do
      @connection.request(method: :get, path: '/some-path', retry_limit: 2, retry_interval: 0.1)
    end

    assert_equal 'Excon request keys :retry_limit, :retry_interval have no effect unless the request is :idempotent',
                 error.message
  end

  def test_warns_on_retry_keys_with_idempotent_false
    error = assert_raises(Excon::Error::Warning) do
      @connection.request(method: :get, idempotent: false, path: '/some-path', retry_errors: [Excon::Error::Socket])
    end

    assert_equal 'Excon request keys :retry_errors have no effect unless the request is :idempotent', error.message
  end

  def test_does_not_warn_on_retry_keys_with_idempotent
    stub_failures(0)

    response = @connection.request(method: :get, idempotent: true, path: '/some-path', retry_limit: 2)

    assert_equal 200, response.status
  end

  def test_does_not_warn_on_retry_keys_with_idempotent_set_on_connection
    stub_failures(0)
    connection = Excon.new('http://127.0.0.1:9292', mock: true, idempotent: true)

    response = connection.request(method: :get, path: '/some-path', retry_limit: 2)

    assert_equal 200, response.status
  end

  # A connection may set retry options for the requests on it that are
  # :idempotent, so requests that aren't don't warn.
  def test_does_not_warn_on_retry_keys_set_on_connection
    stub_failures(0)
    connection = Excon.new('http://127.0.0.1:9292', mock: true, retry_limit: 2)

    response = connection.request(method: :get, path: '/some-path')

    assert_equal 200, response.status
  end
end
