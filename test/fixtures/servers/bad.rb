#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'server')

serve("127.0.0.1", 9292) do |socket|
  request = read_request_head(socket)
  case request
  when %r{^GET /echo\s}
    socket.write "HTTP/1.1 200 OK\r\n"
    socket.write "\r\n"
    socket.write request
  when %r{^GET /eof/no_content_length_and_no_chunking\s}
    socket.write "HTTP/1.1 200 OK\r\n"
    socket.write "\r\n"
    socket.write "hello"
  end
end
