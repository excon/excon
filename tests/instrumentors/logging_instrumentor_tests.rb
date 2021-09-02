require 'logger'
require 'tempfile'

Shindo.tests('logging instrumentor') do
  env_init

  tests("connection logger").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    log_path = Tempfile.create.path
    logger = Logger.new(log_path)
    # omit datetime to simplify test matcher
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: Excon::LoggingInstrumentor,
      logger: logger,
      mock: true
    )

    response = connection.request(method: :get, path: '/logger')

    File.readlines(log_path) == [
      "request: http://127.0.0.1/logger\n",
      "response: body\n"
    ]
  end

  tests("connection logger with query as hash").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    log_path = Tempfile.create.path
    logger = Logger.new(log_path)
    # omit datetime to simplify test matcher
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

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
    File.readlines(log_path) == [
      "request: http://127.0.0.1/logger?test=test\n",
      "response: body\n"
    ]
  end

  Excon.stubs.clear
  env_restore
end
