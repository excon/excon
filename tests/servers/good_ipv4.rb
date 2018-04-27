#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'good')

EM.run do
  EM.start_server("127.0.0.1", 9292, GoodServer)
  $stderr.puts "ready"
end
