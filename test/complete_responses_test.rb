# frozen_string_literal: true

require_relative 'test_helper'

# Responses are parsed completely (body, status line, status, reason phrase,
# remote IP) every time, checked over many requests to catch intermittent
# partial reads.
module CompleteResponseTests
  REQUESTS = 100

  def test_responses_are_complete
    REQUESTS.times do
      assert_complete Excon.get("http://127.0.0.1:9292#{path}")
    end
  end

  private

  def assert_complete(response)
    assert_equal expected_body, response.body
    assert_equal "HTTP/1.1 #{expected_status} #{expected_reason}\r\n", response.status_line
    assert_equal expected_status, response.status
    assert_equal expected_reason, response.reason_phrase
    assert_equal '127.0.0.1', response.remote_ip
  end
end

class CompleteResponsesTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include CompleteResponseTests

  test_server :exec, 'good_ipv4.rb'

  def path = '/chunked/simple'
  def expected_body = 'hello world'
  def expected_status = 200
  def expected_reason = 'OK'
end

class CompleteErrorResponsesTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include CompleteResponseTests

  # Answers GET /error/not_found with a 404 and a body, without
  # Content-Length, then closes the connection.
  test_server :exec, 'error.rb'

  def path = '/error/not_found'
  def expected_body = 'server says not found'
  def expected_status = 404
  def expected_reason = 'Not Found'
end
