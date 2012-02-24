require "stringio"

Shindo.tests('Test Excon debugging') do
  
  def capture_stderr
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = previous_stderr
  end
  
  with_rackup('request_methods.ru') do
      
    tests("Outputs debug statements to stderr if ENV var is set to debug") do
      
      ENV['EXCON_DEBUG_REQUESTS'] = "true"
      
      connection = Excon.new('http://localhost:9292')
      
      string = "GET / HTTP/1.1\r\nContent-Length: 0\r\nHost: localhost:9292\r\n\r\n"      
      tests('A mundane get request').returns(string) do        
        http_request = capture_stderr do         
          connection.get
        end
        http_request
      end

      string = "POST / HTTP/1.1\r\nContent-Length: 4\r\nHost: localhost:9292\r\n\r\nBODY\n"      
      tests('A mundane POST request with a body').returns(string) do        
        http_request = capture_stderr do         
          connection.post(:body => "BODY")
        end
        http_request
      end

    end
    
  end
end