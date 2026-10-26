#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'server')
require File.join(File.expand_path(File.dirname(__FILE__)), 'good')

if RUBY_PLATFORM == 'java'
  $stderr.puts "ready"
  sleep
else
  serve("::1", 9293) do |socket|
    GoodServer.new(socket).run
  end
end
