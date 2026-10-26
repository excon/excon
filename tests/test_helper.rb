TEST_SUITE_DEFAULTS = {
  :connect_timeout  => 5,
  :read_timeout     => 5,
  :write_timeout    => 5
}

require 'bundler/setup'
require 'excon'
require 'webrick'

require './test/support/warning_helpers.rb'
require './test/support/in_process_server.rb'

Excon.set_raise_on_warnings!(true)

PROXY_ENV_VARIABLES = %w{http_proxy https_proxy no_proxy} # All lower-case

def env_init(env={})
  current = {}
  PROXY_ENV_VARIABLES.each do |key|
    current[key] = ENV.delete(key)
    current[key.upcase] = ENV.delete(key.upcase)
  end
  env_stack << current

  env.each do |key, value|
    ENV[key] = value
  end
end

def env_restore
  ENV.update(env_stack.pop)
end

def env_stack
  @env_stack ||= []
end

def with_rackup(name, host="127.0.0.1")
  server = InProcessServer.new(:webrick, name, bind: "tcp://#{host}:9292")
  server.start
  yield
ensure
  server&.stop
end

def with_puma(name, listen='127.0.0.1:9292')
  listen = "tcp://#{listen}" unless listen.include?('://')
  server = InProcessServer.new(:puma, name, bind: listen)
  server.start
  yield
ensure
  server&.stop
end

def with_server(name)
  server = InProcessServer.new(:exec, "#{name}.rb")
  server.start
  yield
ensure
  server&.stop
end
