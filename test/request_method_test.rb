# frozen_string_literal: true

require_relative 'test_helper'

# request_methods.ru answers GET, POST and DELETE on / with the request method
# as the body, and 404s anything else.
class RequestMethodTest < Minitest::Test
  include TestServer

  test_server :webrick, 'request_methods.ru'

  def test_excon_get
    assert_equal 'GET', Excon.get('http://localhost:9292').body
  end

  def test_excon_post
    assert_equal 'POST', Excon.post('http://localhost:9292').body
  end

  def test_excon_delete
    assert_equal 'DELETE', Excon.delete('http://localhost:9292').body
  end

  def test_connection_get
    connection = Excon.new('http://localhost:9292')

    assert_equal 'GET', connection.get.body
  end

  def test_connection_post
    connection = Excon.new('http://localhost:9292')

    assert_equal 'POST', connection.post.body
  end

  def test_connection_delete
    connection = Excon.new('http://localhost:9292')

    assert_equal 'DELETE', connection.delete.body
  end

  def test_does_not_modify_path_argument
    connection = Excon.new('http://localhost:9292')
    # unfrozen, and without a leading '/', which the request adds
    path = +'path'
    connection.get(path: path)

    assert_equal 'path', path
  end
end
