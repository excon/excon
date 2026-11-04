# frozen_string_literal: true

require 'openssl'
require 'socket'
require_relative 'file_path_helpers'

# A minimal HTTP proxy for testing, listening on a free port of 127.0.0.1 in a
# thread of the test process. It records each request it receives (request
# line and headers, as sent) in #requests. Only CONNECT is supported.
#
#   proxy = FakeHTTPProxy.new.start
#   Excon.get('https://127.0.0.1:9443/', proxy: "http://127.0.0.1:#{proxy.port}")
#   proxy.requests # => ["CONNECT 127.0.0.1:9443 HTTP/1.1\r\nHost: ..."]
#   proxy.stop
#
# By default it answers 200 and tunnels to the requested host and port.
# Otherwise:
#
#   status: '407 Proxy Authentication Required' answers with that status (and
#     no body) and closes, without tunneling
#   reply: "..." writes exactly that instead of a response, and closes
#   silent: true never answers, leaving the client waiting
#   terminate_tls: true answers 200, then, instead of tunneling, acts as the
#     target itself: it does the TLS handshake (with the 127.0.0.1
#     certificate in test/fixtures/data), records the request sent through
#     the tunnel in #requests after the CONNECT, and answers it with an
#     empty 200
class FakeHTTPProxy
  attr_reader :port

  def initialize(status: '200 Connection established', reply: nil, silent: false, terminate_tls: false)
    @status = status
    @reply = reply
    @silent = silent
    @terminate_tls = terminate_tls
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
    request = read_request(client)
    record(request)
    return sleep if @silent
    return client.write(@reply) if @reply

    return client.write("HTTP/1.1 #{@status}\r\nContent-Length: 0\r\n\r\n") unless @status.start_with?('200')

    client.write("HTTP/1.1 #{@status}\r\n\r\n")
    @terminate_tls ? answer_as_target(client) : tunnel(client, request)
  rescue IOError, SystemCallError
    nil # the client went away
  ensure
    client.close
  end

  def record(request)
    @mutex.synchronize { @requests << request }
  end

  def answer_as_target(client)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(data_path('127.0.0.1.cert.crt')))
    context.key = OpenSSL::PKey.read(File.read(data_path('127.0.0.1.cert.key')))
    ssl = OpenSSL::SSL::SSLSocket.new(client, context)
    ssl.accept
    record(read_request(ssl))
    ssl.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
  ensure
    ssl&.close
  end

  def read_request(client)
    request = +''
    until (line = client.gets).nil? || line == "\r\n"
      request << line
    end
    request
  end

  # Copies bytes both ways between the client and the CONNECT target until
  # either side closes.
  def tunnel(client, request)
    host, port = request[/\ACONNECT (\S+) /, 1].split(/:(?=\d+\z)/)
    upstream = TCPSocket.new(host, port.to_i)
    loop do
      IO.select([client, upstream]).first.each do |from|
        to = from.equal?(client) ? upstream : client
        to.write(from.readpartial(16_384))
      end
    end
  rescue EOFError
    nil
  ensure
    upstream&.close
  end
end
