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

  end

  with_rackup('proxy.ru') do

    tests('http proxying: http://foo.com:8080') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://localhost:9292')
      response = connection.request(:method => :get, :path => '/bar', :query => {:alpha => 'kappa'})

      tests('response.status').returns(200) do
        response.status
      end

      # must be absolute form for proxy requests
      tests('sent Request URI').returns('http://foo.com:8080/bar?alpha=kappa') do
        response.headers['Sent-Request-Uri']
      end

      tests('sent Host header').returns('foo.com:8080') do
        response.headers['Sent-Host']
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
