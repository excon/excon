# frozen_string_literal: true

require_relative 'test_helper'

class HeaderTest < Minitest::Test
  def setup
    @headers = Excon::Headers.new
    @headers['Exact-Case'] = 'expected'
    @headers['Another-Fixture'] = 'another'
  end

  def test_stores_and_retrieves_as_received
    assert_equal 'expected', @headers['Exact-Case']
  end

  def test_enumerates_keys_as_received
    assert_includes @headers.keys, 'Exact-Case'
    assert_includes @headers.keys, 'Another-Fixture'
  end

  def test_reads_case_insensitively
    assert_equal 'expected', @headers['EXACT-CASE']
  end

  def test_reads_nil_for_missing_key
    assert_nil @headers['Missing-Header']
  end

  def test_assoc_is_case_insensitive
    # returns the downcased key
    assert_equal %w[exact-case expected], @headers.assoc('exact-Case')
  end

  def test_delete_is_case_insensitive
    @headers['Extra'] = 'yes'

    assert_equal 'yes', @headers.delete('extra')
  end

  def test_delete_missing_key_calls_block
    assert_equal 'called with notpresent', @headers.delete('notpresent') { |key| "called with #{key}" }
  end

  def test_fetch_is_case_insensitive
    assert_equal 'expected', @headers.fetch('exact-CASE')
  end

  def test_fetch_missing_key_returns_default
    assert_equal 'default', @headers.fetch('missing', 'default')
  end

  def test_fetch_missing_key_calls_block
    assert_equal 'got missing', @headers.fetch('missing') { |key| "got #{key}" }
  end

  def test_has_key_is_case_insensitive
    assert @headers.key?('EXACT-case')
    refute @headers.key?('missing')
  end

  def test_values_at_is_case_insensitive
    assert_equal %w[expected another], @headers.values_at('exACT-cASE', 'anotheR-fixturE')
  end

  def test_values_at_returns_nil_for_missing_keys
    assert_equal ['expected', nil], @headers.values_at('exact-case', 'missing-header')
  end
end

# response_header.ru answers GET /foo with MixedCase-Header: MixedCase,
# UPPERCASE-HEADER: UPPERCASE and lowercase-header: lowercase. It's used as a
# proxy, so the request for foo.com reaches it whatever the host.
class HeaderResponseTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'response_header.ru'

  def test_get_header_whatever_the_server_capitalization
    response = request_foo

    assert_equal 'MixedCase', response.get_header('mixedcase-header')
    assert_equal 'UPPERCASE', response.get_header('uppercase-header')
    assert_equal 'lowercase', response.get_header('lowercase-header')
  end

  def test_get_header_whatever_the_key_capitalization
    response = request_foo

    assert_equal 'MixedCase', response.get_header('MIXEDCASE-HEADER')
    assert_equal 'MixedCase', response.get_header('MiXeDcAsE-hEaDeR')
  end

  def test_get_header_returns_nil_for_missing_header
    assert_nil request_foo.get_header('missing')
  end

  private

  def request_foo
    connection = Excon.new('http://foo.com:8080', proxy: 'http://127.0.0.1:9292')
    connection.request(method: :get, path: '/foo')
  end
end
