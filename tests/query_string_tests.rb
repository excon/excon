require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

with_rackup('query_string.ru') do
  Shindo.tests('Excon query string variants') do
    connection = Excon.new('http://127.0.0.1:9292')
    
    tests(":query => {:foo => 'bar'}") do

      response = connection.request(:method => :get, :path => '/query', :query => {:foo => 'bar'})
      query_string = response.body[7..-1] # query string sent
      
      tests("query string sent").returns('foo=bar') do
        query_string
      end
      
    end
    
    tests(":query => {:foo => nil}") do

      response = connection.request(:method => :get, :path => '/query', :query => {:foo => nil})
      query_string = response.body[7..-1] # query string sent
      
      tests("query string sent").returns('foo') do
        query_string
      end
      
    end
    
    tests(":query => {:foo => 'bar', :me => nil}") do

      response = connection.request(:method => :get, :path => '/query', :query => {:foo => 'bar', :me => nil})
      query_string = response.body[7..-1] # query string sent
      
      tests("query string sent includes 'foo=bar'").returns(true) do
        query_string.split('&').include?('foo=bar')
      end
      
      tests("query string sent includes 'me'").returns(true) do
        query_string.split('&').include?('me')
      end
      
    end
    
    tests(":query => {:foo => 'bar', :me => 'too'}") do

      response = connection.request(:method => :get, :path => '/query', :query => {:foo => 'bar', :me => 'too'})
      query_string = response.body[7..-1] # query string sent
      
      tests("query string sent includes 'foo=bar'").returns(true) do
        query_string.split('&').include?('foo=bar')
      end
      
      tests("query string sent includes 'me=too'").returns(true) do
        query_string.split('&').include?('me=too')
      end
      
    end
    
  end
end
