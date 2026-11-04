# frozen_string_literal: true

require 'socket'

# A minimal HTTP proxy for testing, listening on a free port of 127.0.0.1 in a
# thread of the test process. It answers every request with the given status
# (and no body) without forwarding it, recording each request it received
# (request line and headers, as sent) in #requests.
#
#   proxy = FakeHTTPProxy.new(status: '407 Proxy Authentication Required').start
#   Excon.get('https://foo.com/', proxy: "http://127.0.0.1:#{proxy.port}")
#   proxy.requests # => ["CONNECT foo.com:443 HTTP/1.1\r\nHost: ..."]
#   proxy.stop
class FakeHTTPProxy
  attr_reader :port

  def initialize(status:)
    @status = status
    @requests = []
    @mutex = Mutex.new
    @threads = []
  end

  def requests
    @mutex.synchronize { @requests.dup }
  end

  def start
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @accept_thread = Thread.new { accept_loop }
    self
  end

  def stop
    @server&.close
    @accept_thread&.join(2)
    @threads.each(&:kill)
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      @threads << Thread.new(client) { |c| handle_client(c) }
    end
  rescue IOError # closed by stop
    nil
  end

  def handle_client(client)
    request = +''
    until (line = client.gets).nil? || line == "\r\n"
      request << line
    end
    @mutex.synchronize { @requests << request }
    client.write("HTTP/1.1 #{@status}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
  rescue IOError, SystemCallError
    nil # the client went away
  ensure
    client.close
  end
end
