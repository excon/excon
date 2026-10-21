# frozen_string_literal: true

require_relative 'test_helper'

class UtilsTest < Minitest::Test
  # connection_uri

  def test_connection_uri_unix
    connection = Excon.new('unix:///some/path', socket: '/tmp/some.sock')
    assert_equal 'unix:///tmp/some.sock', Excon::Utils.connection_uri(connection.data)
  end

  def test_connection_uri_http_without_default_port
    connection = Excon.new('http://foo.com/some/path')
    assert_equal 'http://foo.com', Excon::Utils.connection_uri(connection.data)
  end

  def test_connection_uri_http_include_default_port_adds_default_port
    connection = Excon.new('http://foo.com/some/path', include_default_port: true)
    assert_equal 'http://foo.com:80', Excon::Utils.connection_uri(connection.data)
  end

  def test_connection_uri_http_include_default_port_false_has_no_port
    connection = Excon.new('http://foo.com/some/path', include_default_port: false)
    assert_equal 'http://foo.com', Excon::Utils.connection_uri(connection.data)
  end

  def test_connection_uri_http_omit_default_port_has_no_port
    connection = Excon.new('http://foo.com/some/path', omit_default_port: true)
    assert_equal 'http://foo.com', Excon::Utils.connection_uri(connection.data)
  end

  # request_uri

  def test_request_uri_unix_without_query
    connection = Excon.new('unix:/', socket: '/tmp/some.sock')
    params = { path: '/some/path' }
    assert_equal 'unix:///tmp/some.sock/some/path', Excon::Utils.request_uri(connection.data.merge(params))
  end

  def test_request_uri_unix_with_query
    connection = Excon.new('unix:/', socket: '/tmp/some.sock')
    params = { path: '/some/path', query: { foo: 'this', bar: 'that' } }
    assert_equal 'unix:///tmp/some.sock/some/path?bar=that&foo=this',
                 Excon::Utils.request_uri(connection.data.merge(params))
  end

  def test_request_uri_http_without_query
    connection = Excon.new('http://foo.com')
    params = { path: '/some/path' }
    assert_equal 'http://foo.com/some/path', Excon::Utils.request_uri(connection.data.merge(params))
  end

  def test_request_uri_http_with_query
    connection = Excon.new('http://foo.com')
    params = { path: '/some/path', query: { foo: 'this', bar: 'that' } }
    assert_equal 'http://foo.com/some/path?bar=that&foo=this', Excon::Utils.request_uri(connection.data.merge(params))
  end

  # default_port?

  def test_default_port_http_default
    assert_equal true, Excon::Utils.default_port?(scheme: 'http', port: 80)
  end

  def test_default_port_http_nonstandard
    assert_equal false, Excon::Utils.default_port?(scheme: 'http', port: 9292)
  end

  def test_default_port_https_default
    assert_equal true, Excon::Utils.default_port?(scheme: 'https', port: 443)
  end

  def test_default_port_https_nonstandard
    assert_equal false, Excon::Utils.default_port?(scheme: 'https', port: 8443)
  end

  def test_default_port_unix_socket
    assert_equal false, Excon::Utils.default_port?(scheme: 'unix')
  end

  # escaping

  def test_escape_uri
    assert_equal '/hello%20excon', Excon::Utils.escape_uri('/hello excon')
  end

  def test_unescape_uri
    assert_equal '/hello excon', Excon::Utils.unescape_uri('/hello%20excon')
  end

  def test_unescape_form
    assert_equal 'message=We love excon!', Excon::Utils.unescape_form('message=We+love+excon!')
  end

  # split_header_value

  def test_split_header_value_single
    assert_equal ['value'], Excon::Utils.split_header_value('value')
  end

  def test_split_header_value_multiple
    assert_equal %w[value1 value2], Excon::Utils.split_header_value('value1, value2')
  end

  def test_split_header_value_with_parameters
    assert_equal ['text/html;q=0.5', 'application/json; version=1'],
                 Excon::Utils.split_header_value('text/html;q=0.5, application/json; version=1')
  end

  def test_split_header_value_quoted_comma
    assert_equal ['foo/bar;key="A,B,C"'], Excon::Utils.split_header_value('foo/bar;key="A,B,C"')
  end

  def test_split_header_value_unterminated_quote_does_not_hang
    # previous implementation would hang on this, so test is here to prevent regression
    result = Timeout.timeout(0.1) do
      Excon::Utils.split_header_value('uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu",')
    end
    assert_equal [], result
  end
end
