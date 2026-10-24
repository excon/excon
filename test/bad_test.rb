# frozen_string_literal: true

require_relative 'test_helper'

# bad.rb answers /echo with the request head as the body, and
# /eof/no_content_length_and_no_chunking with 'hello'. Neither response sends
# headers, a Content-Length or chunking, so the body ends when the server
# closes the connection.
class BadServerTest < Minitest::Test
  include TestServer

  test_server :exec, 'bad.rb'

  # header splitting

  def test_rejects_header_key_with_crlf
    assert_raises(Excon::Error::InvalidHeaderKey) do
      connection.request(method: :get, path: '/echo', headers: { "Foo\r\nBar" => 'baz' })
    end
  end

  def test_rejects_header_value_with_crlf
    assert_raises(Excon::Error::InvalidHeaderValue) do
      connection.request(method: :get, path: '/echo', headers: { Foo: "bar\r\nBaz: qux" })
    end
  end

  # body read until EOF

  def test_body_without_content_length_or_chunking_is_read_until_eof
    response = connection.request(method: :get, path: '/eof/no_content_length_and_no_chunking')
    assert_equal 'hello', response.body
  end

  def test_response_block_without_content_length_or_chunking_is_read_until_eof
    body = +''
    response_block = ->(chunk, _remaining, _total) { body << chunk }
    connection.request(method: :get, path: '/eof/no_content_length_and_no_chunking', response_block: response_block)
    assert_equal 'hello', body
  end

  private

  def connection
    Excon.new('http://127.0.0.1:9292')
  end
end

# eof.rb reads the request and closes the connection without responding.
class EofServerTest < Minitest::Test
  include TestServer

  test_server :exec, 'eof.rb'

  def test_closed_connection_without_response_raises_socket_error
    assert_raises(Excon::Error::Socket) { Excon.get('http://127.0.0.1:9292/eof') }
  end
end
