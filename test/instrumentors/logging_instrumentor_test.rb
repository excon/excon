# frozen_string_literal: true

require_relative '../test_helper'

class LoggingInstrumentorTest < Minitest::Test
  include WithoutProxyEnv

  # Logger's default format, e.g. "I, [2026-10-21T13:03:07.183517 #496]  INFO -- : "
  PREFIX = /I, \[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6} ##{Process.pid}\]  INFO -- : /

  # Any object responding to #info works as a logger.
  class TestLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def info(message)
      @messages << message
    end
  end

  def setup
    super
    Excon.stub({ method: :get }, { body: 'body', status: 200 })
  end

  def teardown
    Excon.stubs.clear
    super
  end

  def test_logs_request_and_response_to_given_logger
    logger = TestLogger.new
    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      logger: logger,
      mock: true
    )

    connection.request(method: :get, path: '/logger')

    assert_equal ['request: http://127.0.0.1/logger', 'response: body'], logger.messages
  end

  def test_logs_query_hash_as_query_string
    logger = TestLogger.new
    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      logger: logger,
      mock: true
    )

    connection.request(method: :get, path: '/logger', query: { test: 'test' })

    assert_equal ['request: http://127.0.0.1/logger?test=test', 'response: body'], logger.messages
  end

  def test_default_logger_writes_logger_formatted_lines_to_stderr
    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      mock: true
    )

    _, err = capture_io { connection.request(method: :get, path: '/logger') }

    lines = err.lines
    assert_equal 2, lines.length
    assert_match(%r{\A#{PREFIX}request: http://127\.0\.0\.1/logger\n\z}o, lines[0])
    assert_match(/\A#{PREFIX}response: body\n\z/o, lines[1])
  end
end
