# frozen_string_literal: true

require_relative 'test_helper'

# request_headers.ru answers POST / with the request headers it received, one
# "name: value" line each (names lowercased, with "_" for "-"), in the order
# they were sent.
class RequestHeadersTest < Minitest::Test
  include TestServer

  test_server :webrick, 'request_headers.ru'

  def test_sends_nil_header_with_empty_value
    response = Excon.post('http://localhost:9292', headers: { one: 1, two: nil, three: 3 })

    assert_includes response.body, 'two:'
  end

  def test_sends_host_header_first
    response = Excon.post('http://localhost:9292/')

    assert_equal 'host: localhost:9292', response.body.lines.first.chomp
  end

  def test_overrides_default_headers_regardless_of_casing
    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.post(headers: { 'accept' => 'application/json' })

    # only the given value, not Excon's default 'Accept: */*' as well
    assert_equal ['accept: application/json'], response.body.lines.map(&:chomp).grep(/\Aaccept:/)
  end
end
