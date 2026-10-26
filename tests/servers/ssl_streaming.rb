#!/usr/bin/env ruby
# frozen_string_literal: true

require 'openssl'
require File.join(__dir__, 'server')

# tests/rackups/streaming.ru over TLS: sends 'Hello', 'streamy' and 'world',
# sleeping 0.1s before each, then closes the connection.
# /streamed/fixed_length also sends a Content-Length.
data = File.join(__dir__, '..', 'data')
context = OpenSSL::SSL::SSLContext.new
context.key = OpenSSL::PKey::RSA.new(File.read(File.join(data, '127.0.0.1.cert.key')))
context.cert = OpenSSL::X509::Certificate.new(File.read(File.join(data, '127.0.0.1.cert.crt')))

pieces = %w[Hello streamy world]

serve('127.0.0.1', 9292) do |socket|
  ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
  begin
    ssl.accept
    request = read_request_head(ssl)
    ssl.write "HTTP/1.1 200 OK\r\n"
    ssl.write "Content-Length: #{pieces.join.length}\r\n" if request.start_with?('GET /streamed/fixed_length ')
    ssl.write "\r\n"
    ssl.flush
    pieces.each do |piece|
      sleep(0.1)
      ssl.write piece
      ssl.flush
    end
  rescue OpenSSL::SSL::SSLError
    # client went away mid-handshake, nothing to do
  ensure
    ssl.close
  end
end
