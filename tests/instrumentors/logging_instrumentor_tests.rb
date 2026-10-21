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

  Excon.stubs.clear
  env_restore
end
