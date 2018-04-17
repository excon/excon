require 'logger'

Shindo.tests('logging instrumentor') do
  env_init

  tests("connection logger").returns(true) do
    Excon.stub({:method => :get}, {body: 'body', status: 200})

    log_path = "/tmp/excon_#{Time.now.to_i}.txt"
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
    File.readlines(log_path)[1..2] == [
      "request: http://127.0.0.1/logger\n",
      "response: body\n"
    ]
  end
end
