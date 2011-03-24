require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

Shindo.tests('Excon proxy support') do

  tests('proxy configuration') do
    
    tests('no proxy') do
      connection = Excon.new('http://foo.com')
      
      tests('connection.proxy').returns(nil) do
        connection.proxy
      end
    end
    
    tests('with fully-specified proxy: https://myproxy.net:8080') do
      connection = Excon.new('http://foo.com', :proxy => 'https://myproxy.net:8080')
      
      tests('connection.proxy.host').returns('myproxy.net') do
        connection.proxy[:host]
      end
      
      tests('connection.proxy.port').returns(8080) do
        connection.proxy[:port]
      end
      
      tests('connection.proxy.scheme').returns('https') do
        connection.proxy[:scheme]
      end
    end
    
    tests('with host-only proxy: myproxy:8888') do
      connection = Excon.new('http://foo.com', :proxy => 'myproxy.net:8888')
      
      tests('connection.proxy.host').returns('myproxy.net') do
        connection.proxy[:host]
      end
      
      tests('connection.proxy.port').returns(8888) do
        connection.proxy[:port]
      end
      
      tests('connection.proxy.scheme').returns('http') do
        connection.proxy[:scheme]
      end
    end
    
  end

  with_rackup('proxy.ru') do
    
    tests('http proxy connection') do
      connection = Excon.new('http://foo.com', :proxy => 'localhost:9292')
    
      http_thread = Thread.new {
        response = connection.request(:method => :get, :path => '/bar')
      }
      response = http_thread.value
    
      tests('response.status').returns(200) do
        response.status
      end
    
      tests('sent Proxy-Connection header').returns('Keep-Alive') do
        response.headers['Sent-Proxy-Connection']
      end
    
      tests('response.body (proxied content)').returns('proxied content') do
        response.body
      end
    end
    
  end

end

