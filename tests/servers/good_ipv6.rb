#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'good')

EM.run do
  EM.start_server("::1", 9293, GoodServer) unless RUBY_PLATFORM == 'java'
  $stderr.puts "ready"
end
