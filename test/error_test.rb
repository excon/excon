# frozen_string_literal: true

require_relative 'test_helper'

class ErrorTest < Minitest::Test
  PERTINENT_STATUS_CODES = [
    100,
    101,
    (200..206).to_a,
    (300..305).to_a,
    307, # 306 is unused (RFC 9110 15.4.8)
    (400..417).to_a,
    422,
    429,
    (500..504).to_a
  ].flatten.freeze

  # Regression against e300458f2d9330cb265baeb8973120d08c665d9
  def test_status_errors_cover_pertinent_status_codes
    assert_equal PERTINENT_STATUS_CODES, Excon::Error.status_errors.keys
  end

  def test_new_returns_an_error
    assert_instance_of Excon::Error, Excon::Error.new('bar')
  end

  # Excon.new / Connection.new validation

  def test_new_raises_for_bad_uris
    error = assert_raises(ArgumentError) { Excon.new('foo') }
    assert_includes error.message, 'foo'
  end

  def test_new_raises_for_bad_paths
    error = assert_raises(URI::InvalidURIError) do
      Excon.new('http://localhost', path: "foo\r\nbar: baz")
    end
    assert_includes error.message, 'foo\r\nbar: baz'
  end

  def test_new_raises_invalid_parameter_for_url_with_nil_host
    # missing // after the scheme
    error = assert_raises(Excon::Error::InvalidParameter) do
      Excon.new('https:/registry.example.com/package')
    end
    assert_includes error.message, 'host is required'
  end

  def test_new_raises_invalid_parameter_when_host_nil_overrides_url
    error = assert_raises(Excon::Error::InvalidParameter) do
      Excon.new('https://registry.example.com/package', host: nil)
    end
    assert_includes error.message, 'host is required'
  end

  def test_connection_new_without_host_raises_invalid_parameter
    error = assert_raises(Excon::Error::InvalidParameter) do
      Excon::Connection.new(scheme: 'https', path: '/package', port: 443).get
    end
    assert_includes error.message, 'host is required'
  end

  # backwards compatibility between Excon::Error and legacy Excon::Errors

  def test_raise_standard_error_catch_standard_error
    assert_raises(Excon::Error) { raise Excon::Error::Client, 'foo' }
  end

  def test_raise_legacy_error_catch_legacy_error
    assert_raises(Excon::Errors::Error) { raise Excon::Errors::Error, 'bar' }
  end

  def test_raise_standard_error_catch_legacy_error
    assert_raises(Excon::Errors::Error) { raise Excon::Error::NotFound, 'bar' }
  end

  def test_raise_status_error_catch_standard_error
    assert_raises(Excon::Error) { raise Excon::Error.status_error({ expects: 200 }, { status: 400 }) }
  end

  def test_raise_status_error_catch_legacy_error
    assert_raises(Excon::Errors::BadRequest) { raise Excon::Error.status_error({ expects: 200 }, { status: 400 }) }
  end

  def test_raise_legacy_status_error_catch_legacy_error
    assert_raises(Excon::Errors::BadRequest) { raise Excon::Errors.status_error({ expects: 200 }, { status: 400 }) }
  end

  def test_raise_legacy_status_error_catch_standard_error
    assert_raises(Excon::Error) { raise Excon::Errors.status_error({ expects: 200 }, { status: 400 }) }
  end
end

class ErrorMessageTest < Minitest::Test
  include TestServer

  test_server :exec, 'error.rb'

  STATUS = 'Expected(200) <=> Actual(404 Not Found)'

  def test_message_excludes_request_and_response_info_by_default
    message = not_found_message
    assert_includes message, STATUS
    refute_includes message, 'excon.error.request'
    refute_includes message, 'excon.error.response'
  end

  def test_message_includes_only_request_info_with_debug_request
    message = not_found_message(debug_request: true)
    assert_includes message, STATUS
    assert_includes message, 'excon.error.request'
    refute_includes message, 'excon.error.response'
  end

  def test_message_includes_only_response_info_with_debug_response
    message = not_found_message(debug_response: true)
    assert_includes message, STATUS
    refute_includes message, 'excon.error.request'
    assert_includes message, 'excon.error.response'
  end

  def test_message_includes_request_and_response_info_with_both
    message = not_found_message(debug_request: true, debug_response: true)
    assert_includes message, STATUS
    assert_includes message, 'excon.error.request'
    assert_includes message, 'excon.error.response'
  end

  private

  def not_found_message(**options)
    error = assert_raises(Excon::Errors::HTTPStatusError) do
      Excon.get('http://127.0.0.1:9292/error/not_found', expects: 200, **options)
    end
    error.message
  end
end
