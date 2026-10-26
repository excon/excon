# frozen_string_literal: true

require_relative 'test_helper'

class ConnectionTest < Minitest::Test
  def test_new_without_arguments_does_not_raise
    refute_nil Excon::Connection.new
  end

  # Each URL is used as both the target and the proxy, so its credentials end
  # up in data[:user]/data[:password], data[:proxy] and the Authorization and
  # Proxy-Authorization headers.

  def test_inspect_redacts_user_and_password
    connection = connection_with_credentials('http://user1:pass1@foo.com/')

    assert_inspect_conceals connection, 'Basic dXNlcjE6cGFzczE=', 'pass1'
    assert_passwords_unchanged connection, 'pass1'
  end

  def test_inspect_redacts_escaped_email_user_and_password
    connection = connection_with_credentials('http://foo%40bar.com:pass1@foo.com/')

    assert_inspect_conceals connection, 'Basic Zm9vQGJhci5jb206cGFzczE=', 'pass1'
    assert_passwords_unchanged connection, 'pass1'
  end

  def test_inspect_redacts_user_without_password
    connection = connection_with_credentials('http://three_user@foo.com/')

    assert_inspect_conceals connection, 'Basic dGhyZWVfdXNlcjo='
    # no password to conceal
    assert_nil connection.data[:password]
    assert_nil connection.data[:proxy][:password]
  end

  def test_inspect_redacts_password_without_user
    connection = connection_with_credentials('http://:derppass@foo.com/')

    assert_inspect_conceals connection, 'Basic OmRlcnBwYXNz', 'derppass'
    assert_passwords_unchanged connection, 'derppass'
  end

  private

  def connection_with_credentials(url)
    Excon.new(url, proxy: url)
  end

  # secrets: the Authorization/Proxy-Authorization header value, then the
  # password (as data[:password] and data[:proxy][:password]), if any
  def assert_inspect_conceals(connection, *secrets)
    inspected = connection.inspect
    secrets.each { |secret| refute_includes inspected, secret }
  end

  # inspect redacts a copy; the connection keeps the real passwords
  def assert_passwords_unchanged(connection, password)
    assert_equal password, connection.data[:password]
    assert_equal password, connection.data[:proxy][:password]
  end
end

# basic.ru answers GET /foo with "foo" and GET /bar with "bar".
class ConnectionServerTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'basic.ru'

  def test_socket_connects_and_sets_remote_ip
    connection = Excon::Connection.new(
      host: '127.0.0.1',
      hostname: '127.0.0.1',
      nonblock: false,
      port: 9292,
      scheme: 'http',
      ssl_verify_peer: false
    )
    connection.send(:socket) # creates and connects the socket

    assert_equal '127.0.0.1', connection.data[:remote_ip]
  end

  def test_persistent_connection_reuses_socket_for_requests
    connection = Excon.new('http://127.0.0.1:9292', persistent: true)

    assert_equal 'foo', connection.request(path: '/foo', method: 'get').body
    assert_equal 'foo', connection.request(path: '/foo', method: 'get').body
  end

  def test_persistent_connection_resets_after_interrupted_request
    connection = Excon.new('http://127.0.0.1:9292', persistent: true)
    connection.request(path: '/foo', method: 'get')

    # interrupt a request partway, which can leave its response unread on
    # the socket
    begin
      Timeout.timeout(0.0000000001) do
        connection.request(path: '/foo', method: 'get')
      end
    rescue Timeout::Error
      nil
    end

    assert_equal 'bar', connection.request(path: '/bar', method: 'get').body
  end

  def test_forked_child_does_not_reuse_parent_socket
    skip 'Process.fork is not available' unless Process.respond_to?(:fork)

    connection = Excon.new('http://127.0.0.1:9292', persistent: true)
    connection.request(path: '/foo', method: 'get')

    refute_equal connection.send(:socket).object_id, socket_id_in_child(connection)
  end

  private

  def socket_id_in_child(connection)
    IO.pipe do |read, write|
      pid = fork do
        write.write(connection.send(:socket).object_id)
        exit!(0)
      end
      write.close
      Process.waitpid(pid)
      read.read.to_i
    end
  end
end
