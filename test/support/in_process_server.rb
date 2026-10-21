# frozen_string_literal: true

require 'puma'
require 'rack'
require 'rackup/handler/webrick'
require 'stringio'
require 'uri'
require 'webrick'

# Runs a test server (a rackup in tests/rackups or a socket server in
# tests/servers) in a thread of the test process. Starting each one in its
# own process instead is slow, especially on JRuby, where every server boots
# a JVM and reloads bundler, rack and sinatra.
#
#   server = InProcessServer.new(:webrick, 'basic.ru').start
#   Excon.get('http://127.0.0.1:9292/')
#   server.stop
#
# Used by both the minitest (test/) and shindo (tests/) suites.
class InProcessServer
  FIXTURES = File.expand_path('../../tests', __dir__)
  DEFAULT_BIND = 'tcp://127.0.0.1:9292'
  START_TIMEOUT = 10

  # Evaluates a rackup, returning the app it runs (or nil for the ssl
  # rackups, which start their own server). instance_eval scopes the classes
  # a rackup defines to its builder, so rackups reusing a class name (App)
  # don't reopen each other's classes.
  def self.rackup_app(file)
    path = File.join(FIXTURES, 'rackups', file)
    builder = Rack::Builder.new
    builder.instance_eval(File.read(path), path)
    builder.to_app unless Thread.current[:server_started]
  end

  module QuietWEBrick
    # Logs to the server's buffer instead of stderr and hands the server to
    # start_webrick once it is listening.
    def run(app, **options)
      options = { Logger: WEBrick::Log.new(Thread.current[:server_log]), AccessLog: [] }.merge(options)
      super(app, **options) do |server|
        yield server if block_given?
        Thread.current[:server_started] = true
        Thread.current[:server_queue] << server
      end
    end
  end
  Rackup::Handler::WEBrick.singleton_class.prepend(QuietWEBrick)

  attr_reader :bind

  # kind: :webrick or :puma (file is a rackup), or :exec (file is a socket
  # server, which binds its own address)
  # bind: tcp://host:port or unix:///path (ssl rackups bind their own port)
  def initialize(kind, file, bind: nil)
    @kind = kind
    @file = file
    @bind = URI.parse(bind || DEFAULT_BIND)
  end

  def start
    send(:"start_#{@kind}")
    self
  end

  def stop
    send(:"stop_#{@kind}")
    true
  end

  private

  def host
    @bind.host.delete('[]')
  end

  def unix?
    @bind.scheme == 'unix'
  end

  def start_webrick
    @log = StringIO.new
    queue = Queue.new
    @thread = Thread.new do
      Thread.current[:server_log] = @log
      Thread.current[:server_queue] = queue
      app = self.class.rackup_app(@file)
      Rackup::Handler::WEBrick.run(app, Host: host, Port: @bind.port) unless Thread.current[:server_started]
    rescue Exception => e # rubocop:disable Lint/RescueException
      queue << e
    end
    @server = queue.pop
    raise @server if @server.is_a?(Exception)
  end

  def stop_webrick
    @server.shutdown if @server.is_a?(WEBrick::GenericServer)
    @thread.kill unless @thread.nil? || @thread.join(5)
    dump_errors
  end

  # Prints errors the server logged, apart from expected TLS failures.
  def dump_errors
    in_err = false
    @log&.string&.each_line do |line|
      if line.match?(/(ERROR|Error)/)
        in_err = !line.match?(/(null cert chain|did not return a certificate|SSL_read:: internal error)/)
        puts if in_err
      end
      puts line if in_err
    end
  end

  def start_puma
    app = self.class.rackup_app(@file)
    if unix?
      # On JRuby, puma's reactor intermittently misses requests arriving on
      # unix sockets, leaving them unanswered until the client times out.
      # Hand each connection straight to a worker thread instead.
      @server = Puma::Server.new(app, nil, queue_requests: false)
      @server.add_unix_listener(@bind.path)
    else
      @server = Puma::Server.new(app)
      @server.add_tcp_listener(host, @bind.port)
    end
    @server.run
  end

  def stop_puma
    @server&.stop(true)
    File.delete(@bind.path) if unix? && File.exist?(@bind.path)
  end

  # Socket servers call serve (tests/servers/server.rb), which exposes the
  # listening socket and client sockets as thread variables once listening.
  def start_exec
    @thread = Thread.new do
      Thread.current.report_on_exception = false # raised by join below
      load File.join(FIXTURES, 'servers', @file)
    end
    deadline = Time.now + START_TIMEOUT
    until @thread[:tcp_server]
      unless @thread.alive?
        # the server failed to start, so there is nothing to stop
        thread = @thread
        @thread = nil
        thread.join # raises the error
      end
      raise "#{@file} did not start listening within #{START_TIMEOUT}s" if Time.now > deadline

      sleep(0.01)
    end
  end

  def stop_exec
    return if @thread.nil?

    @thread.kill.join
    @thread[:tcp_server]&.close
    @thread[:clients]&.each(&:close)
  end
end
