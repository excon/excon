Shindo.tests('Excon response header support') do

  with_rackup('response_header.ru') do

    tests('Response#header') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://localhost:9292')
      response = connection.request(:method => :get, :path => '/foo')

      tests('with variable header capitalization') do
        
        tests('response.header("content-type")').returns('text/html') do
          response.header("content-type")
        end
        
        tests('response.header("custom-header")').returns('foo') do
          response.header("custom-header")
        end
        
        tests('response.header("lowercase-header")').returns('bar') do
          response.header("lowercase-header")
        end
        
      end
      
      tests('when provided key capitalization varies') do
        
        tests('response.header("CONTENT-TYPE")').returns('text/html') do
          response.header("CONTENT-TYPE")
        end
        
        tests('response.header("CoNtEnT-TyPe")').returns('text/html') do
          response.header("CoNtEnT-TyPe")
        end
        
      end
      
      tests('when header is unavailable') do
        
        tests('response.header("missing")').returns(nil) do
          response.header("missing")
        end
        
      end

      # tests('response.status').returns(200) do
      #   response.status
      # end
      # 
      # # must be absolute form for proxy requests
      # tests('sent Request URI').returns('http://foo.com:8080/bar?alpha=kappa') do
      #   response.headers['Sent-Request-Uri']
      # end
      # 
      # tests('sent Host header').returns('foo.com:8080') do
      #   response.headers['Sent-Host']
      # end
      # 
      # tests('sent Proxy-Connection header').returns('Keep-Alive') do
      #   response.headers['Sent-Proxy-Connection']
      # end
      # 
      # tests('response.body (proxied content)').returns('proxied content') do
      #   response.body
      # end
    end

  end

end
