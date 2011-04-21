Shindo.tests('Excon response header support') do

  with_rackup('response_header.ru') do

    tests('Response#get_header') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://localhost:9292')
      response = connection.request(:method => :get, :path => '/foo')

      tests('with variable header capitalization') do
        
        tests('response.get_header("content-type")').returns('text/html') do
          response.get_header("content-type")
        end
        
        tests('response.get_header("custom-header")').returns('foo') do
          response.get_header("custom-header")
        end
        
        tests('response.get_header("lowercase-header")').returns('bar') do
          response.get_header("lowercase-header")
        end
        
      end
      
      tests('when provided key capitalization varies') do
        
        tests('response.get_header("CONTENT-TYPE")').returns('text/html') do
          response.get_header("CONTENT-TYPE")
        end
        
        tests('response.get_header("CoNtEnT-TyPe")').returns('text/html') do
          response.get_header("CoNtEnT-TyPe")
        end
        
      end
      
      tests('when header is unavailable') do
        
        tests('response.get_header("missing")').returns(nil) do
          response.get_header("missing")
        end
        
      end
      
    end

  end

end
