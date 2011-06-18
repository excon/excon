Shindo.tests('Excon response header support') do

  with_rackup('response_header.ru') do

    tests('Response#get_header') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://localhost:9292')
      response = connection.request(:method => :get, :path => '/foo')

      tests('with variable header capitalization') do
        
        tests('response.get_header("mixedcase-header")').returns('MixedCase') do
          response.get_header("mixedcase-header")
        end
        
        tests('response.get_header("uppercase-header")').returns('UPPERCASE') do
          response.get_header("uppercase-header")
        end
        
        tests('response.get_header("lowercase-header")').returns('lowercase') do
          response.get_header("lowercase-header")
        end
        
      end
      
      tests('when provided key capitalization varies') do
        
        tests('response.get_header("MIXEDCASE-HEADER")').returns('MixedCase') do
          response.get_header("MIXEDCASE-HEADER")
        end
        
        tests('response.get_header("MiXeDcAsE-hEaDeR")').returns('MixedCase') do
          response.get_header("MiXeDcAsE-hEaDeR")
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
