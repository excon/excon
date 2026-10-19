require 'socket'

# Accepts connections on +host+:+port+ and yields each socket to the block in
# its own thread, closing it once the block returns. Prints "ready" to stderr
# once listening, which is what the test helpers wait for.
def serve(host, port)
  server = TCPServer.new(host, port)
  $stderr.puts "ready"
  loop do
    Thread.new(server.accept) do |socket|
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
