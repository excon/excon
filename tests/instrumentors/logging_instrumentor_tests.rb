require 'stringio'

# any object responding to #info works as a logger
class TestLogger
  attr_reader :messages

  def initialize
    @messages = []
  end

  def info(message)
    @messages << message
  end
end

Shindo.tests('logging instrumentor') do
  env_init

  tests("connection logger").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    logger = TestLogger.new

    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      logger: logger,
      mock: true
    )

    response = connection.request(method: :get, path: '/logger')

    logger.messages == [
      "request: http://127.0.0.1/logger",
      "response: body"
    ]
  end

  tests("connection logger with query as hash").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    logger = TestLogger.new

    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      logger: logger,
      mock: true
    )
    response = connection.request(
      method: :get,
      path: '/logger',
      query: {test: 'test'}
    )
    logger.messages == [
      "request: http://127.0.0.1/logger?test=test",
      "response: body"
    ]
  end

  tests("default logger writes Logger formatted lines to stderr").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      mock: true
    )

    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      connection.request(method: :get, path: '/logger')
      lines = $stderr.string.lines
    ensure
      $stderr = original_stderr
    end

    prefix = /\AI, \[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6} ##{Process.pid}\]  INFO -- : /
    lines.length == 2 &&
      lines[0].match?(%r{#{prefix}request: http://127\.0\.0\.1/logger\n\z}) &&
      lines[1].match?(/#{prefix}response: body\n\z/)
  end

  Excon.stubs.clear
  env_restore
end
