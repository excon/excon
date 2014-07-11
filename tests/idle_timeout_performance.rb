#!/usr/bin/env ruby

require 'bundler/setup'
require 'excon'
require 'timeout'

SERVER_PATH = File.expand_path('../servers/good.rb', __FILE__)
SERVER_URI = 'http://127.0.0.1:9292'

def with_server
  r, w = IO.pipe
  pid = spawn(SERVER_PATH, :out => '/dev/null', :err => w.fileno)
  w.close
  until r.gets =~ /ready/; end
  yield
ensure
  r.close
  Process.kill(9, pid)
  Process.wait(pid)
end

def benchmark(tag)
  connection = yield
  begin
    sec = 3
    count = 0
    Timeout.timeout(sec) do
      while true
        connection.get
        count += 1
      end
    end
  rescue TimeoutError
    puts "\e[2K\e[0G#{ count / sec } rps : %s" % tag
  end
end

with_server do

  uri = SERVER_URI + '/echo/request_count'

  benchmark 'non-persistent' do
    Excon.new(uri)
  end

  benchmark 'persistent, :detect_timeout => false' do
    Excon.new(uri, :persistent => true, :detect_timeout => false)
  end

  benchmark 'persistent, :detect_timeout => true' do
    Excon.new(uri, :persistent => true)
  end

  # server will silently close the connection every 2nd request
  uri = SERVER_URI + '/content-length/idle_timeout'

  # :detect_timeout will re-establish the socket
  begin
    benchmark 'persistent, idle timeout, :detect_timeout => true' do
      Excon.new(uri, :persistent => true)
    end
  rescue Excon::Errors::SocketError
    # server closed connection during the request (after socket#alive?)
    print '.'
    retry
  end

  # :idempotent will retry the failed requests
  benchmark 'persistent, idle timeout, :detect_timeout => false, :idempotent => true' do
    Excon.new(uri, :persistent => true, :detect_timeout => false, :idempotent => true)
  end

end
