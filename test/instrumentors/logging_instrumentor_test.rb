# frozen_string_literal: true

require_relative '../test_helper'

class LoggingInstrumentorTest < Minitest::Test
  # Logger's default format, e.g. "I, [2026-10-21T13:03:07.183517 #496]  INFO -- : "
  PREFIX = /I, \[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6} ##{Process.pid}\]  INFO -- : /

  def setup
    Excon.stub({ method: :get }, { body: 'body', status: 200 })
  end

  def teardown
    Excon.stubs.clear
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
