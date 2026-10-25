# frozen_string_literal: true

require_relative 'test_helper'

# query_string.ru answers GET /query with "query: " followed by the query
# string it received.
class QueryStringTest < Minitest::Test
  include TestServer

  test_server :webrick, 'query_string.ru'

  def test_single_param
    assert_equal 'foo=bar', query_sent(foo: 'bar')
  end

  def test_nil_value_sends_key_only
    assert_equal 'foo', query_sent(foo: nil)
  end

  def test_value_and_nil_value
    params = query_sent(foo: 'bar', me: nil).split('&')

    assert_includes params, 'foo=bar'
    assert_includes params, 'me'
  end

  def test_two_params
    params = query_sent(foo: 'bar', me: 'too').split('&')

    assert_includes params, 'foo=bar'
    assert_includes params, 'me=too'
  end

  # Rails/PHP style arrays: an array value repeats the key, here with a
  # square brackets suffix, which is escaped.
  def test_array_value_repeats_key
    params = query_sent('foo[]' => %w[bar baz], :me => 'too').split('&')

    assert_includes params, 'foo%5B%5D=bar'
    assert_includes params, 'foo%5B%5D=baz'
    assert_includes params, 'me=too'
  end

  def test_escapes_key_and_value
    assert_equal 'foo%25%3D%23=bar%25%3D%23', query_sent('foo%=#' => 'bar%=#')
  end

  def test_escapes_key_with_nil_value
    assert_equal 'foo%25%3D%23', query_sent('foo%=#' => nil)
  end

  private

  def query_sent(query)
    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(method: :get, path: '/query', query: query)
    response.body.delete_prefix('query: ')
  end
end
