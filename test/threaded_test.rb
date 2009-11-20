require File.join(File.dirname(__FILE__), '..', 'lib/excon')

connection = Excon.new('http://127.0.0.1:9292')

long_thread = Thread.new {
  response = connection.request(:method => 'GET', :path => '/id/1/wait/5')
  raise "long request got the short response" unless response.body == '1'
}

short_thread = Thread.new {
  response = connection.request(:method => 'GET', :path => '/id/2/wait/1')
  raise "short request got the long response" unless response.body == '2'
}

long_thread.join
