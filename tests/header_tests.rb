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
      
    end

  end

end
