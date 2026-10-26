#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'server')

serve("127.0.0.1", 9292) do |socket|
  case read_request_head(socket)
  when %r{^GET /error/not_found\s}
    socket.write "HTTP/1.1 404 Not Found\r\n"
    socket.write "\r\n"
    socket.write "server says not found"
  end
end
