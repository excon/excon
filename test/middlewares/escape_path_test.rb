# frozen_string_literal: true

require_relative '../test_helper'

# basic.ru answers GET '/echo dirty' (once unescaped) with 200 and anything
# else it doesn't know with 404, so a 200 means the path reached the server
# escaped exactly once.
class EscapePathTest < Minitest::Test
  include TestServer

  test_server :webrick, 'basic.ru'

  def connection
    Excon::Connection.new(
      host: '127.0.0.1',
      hostname: '127.0.0.1',
      middlewares: Excon.defaults[:middlewares] + [Excon::Middleware::EscapePath],
      nonblock: false,
      port: 9292,
      scheme: 'http',
      ssl_verify_peer: false
    )
  end

  def test_leaves_encoded_path_as_is
    # escaping it again would send /echo%2520dirty, which 404s
    response = connection.request(method: :get, path: '/echo%20dirty')

    assert_equal 200, response.status
  end

  def test_encodes_unencoded_path
    response = connection.request(method: :get, path: '/echo dirty')

    assert_equal 200, response.status
  end
end
