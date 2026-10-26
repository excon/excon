#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'server')

# closes every connection without responding
serve("127.0.0.1", 9292) do |socket|
  read_request_head(socket)
end
