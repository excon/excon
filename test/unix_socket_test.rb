# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

# Connections over a UNIX socket. The Host header tests use a mock that
# echoes the request headers back as the JSON response body, so no socket
# needs to exist.
class UnixSocketTest < Minitest::Test
  def teardown
    Excon.stubs.clear
  end

  # Excon.new parses the URL, unlike Excon::Connection.new. Version 0.12.0 of
  # the uri gem changed from returning nil for no host to returning an empty
  # string, which this URL exercises.
  def test_excon_new_accepts_a_unix_url_with_no_host
    connection = Excon.new('unix:///', socket: '/tmp/foo')

    assert_equal 'unix', connection.data[:scheme]
    assert_equal '/tmp/foo', connection.data[:socket]
  end

  def test_sends_an_empty_host_header_by_default
    headers = request_headers

    assert_equal '', headers['Host']
  end

  def test_keeps_an_explicit_host_header
    headers = request_headers('Host' => 'localhost')

    assert_equal 'localhost', headers['Host']
  end

  private

  def request_headers(headers = {})
    Excon.stub do |request|
      { body: request[:headers].to_json, status: 200 }
    end
    connection = Excon::Connection.new(scheme: 'unix', socket: '/tmp/x.sock', mock: true)
    JSON.parse(connection.get(path: '/path', headers: headers).body)
  end
end
