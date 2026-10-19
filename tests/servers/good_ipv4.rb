#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__)), 'server')
require File.join(File.expand_path(File.dirname(__FILE__)), 'good')

serve("127.0.0.1", 9292) do |socket|
  GoodServer.new(socket).run
end
