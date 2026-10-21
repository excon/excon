require 'socket'

# Accepts connections on +host+:+port+ and yields each socket to the block in
# its own thread, closing it once the block returns. Once listening, it prints
# "ready" to stderr when run as a script, or exposes the server and its client
# sockets as thread variables when loaded in a thread by the test helpers, so
# they know when to start and what to close afterwards.
def serve(host, port)
  server = TCPServer.new(host, port)
  clients = []
  if Thread.current == Thread.main
    $stderr.puts "ready"
  else
    Thread.current[:clients] = clients
    Thread.current[:tcp_server] = server
  end
  loop do
    clients << server.accept
    Thread.new(clients.last) do |socket|
      socket.binmode
      yield socket
    rescue EOFError, IOError, SystemCallError
      # client went away, nothing to do
    ensure
      socket.close unless socket.closed?
    end
  end
end

# Reads the request-line and headers, up to and including the blank line.
def read_request_head(socket)
  head = +''
  while (line = socket.gets("\r\n"))
    head << line
    break if line == "\r\n"
  end
  head
end
