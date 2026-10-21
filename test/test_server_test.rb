# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

class TestServerLifecycleTest < Minitest::Test
  SERVERS = {
    webrick: [:webrick, 'basic.ru'],
    puma_tcp: [:puma, 'streaming.ru'],
    puma_unix: [:puma, 'streaming.ru', "unix://#{File.join(Dir.tmpdir, 'excon-puma.socket')}"],
    exec: [:exec, 'good_ipv4.rb']
  }.freeze

  SERVERS.each do |name, (plugin, file, bind)|
    define_method(:"test_#{name}_starts_and_stops") do
      args = { plugin => send(:"#{plugin}_path", file) }
      args[:bind] = bind if bind
      server = Excon::Test::Server.new(args)
      unix = server.bind.scheme == 'unix'

      assert_instance_of Excon::Test::Server, server

      assert server.start
      assert File.socket?(server.bind.path) if unix

      assert server.stop
      refute File.exist?(server.bind.path) if unix
    end
  end
end

class InProcessServerLifecycleTest < Minitest::Test
  SERVERS = {
    webrick: [:webrick, 'basic.ru'],
    puma_tcp: [:puma, 'streaming.ru'],
    puma_unix: [:puma, 'streaming.ru', "unix://#{File.join(Dir.tmpdir, 'excon-puma.socket')}"],
    exec: [:exec, 'good_ipv4.rb']
  }.freeze

  SERVERS.each do |name, (kind, file, bind)|
    define_method(:"test_#{name}_starts_and_stops") do
      server = InProcessServer.new(kind, file, bind: bind)
      unix = server.bind.scheme == 'unix'

      assert_same server, server.start
      if unix
        assert File.socket?(server.bind.path)
      else
        TCPSocket.new('127.0.0.1', 9292).close
      end

      assert server.stop
      if unix
        refute File.exist?(server.bind.path)
      else
        assert_raises(Errno::ECONNREFUSED) { TCPSocket.new('127.0.0.1', 9292) }
      end
    end
  end

  def test_ssl_rackup_binds_its_own_port
    server = InProcessServer.new(:webrick, 'ssl.ru').start
    response = Excon.get('https://127.0.0.1:9443/content-length/100', ssl_verify_peer: false)
    assert_equal 200, response.status
  ensure
    server&.stop
  end

  def test_exec_raises_when_the_server_cannot_start
    blocker = TCPServer.new('127.0.0.1', 9292)
    assert_raises(Errno::EADDRINUSE) { InProcessServer.new(:exec, 'good_ipv4.rb').start }
  ensure
    blocker&.close
  end
end

class TestServerHelperTest < Minitest::Test
  include TestServer

  test_server :webrick, 'basic.ru'

  def test_server_is_running_during_tests
    assert_instance_of InProcessServer, server
    assert_equal 200, Excon.get('http://127.0.0.1:9292/content-length/100').status
  end
end
