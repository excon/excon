Shindo.tests('Excon request methods') do

  with_rackup('request_methods.ru') do

    tests 'one-offs' do
      
      tests('Excon.get').returns('GET') do
        Excon.get('http://127.0.0.1:9292').body
      end
      
      tests('Excon.post').returns('POST') do
        Excon.post('http://127.0.0.1:9292').body
      end
      
    end
    
    tests 'with a connection object' do
      
      connection = Excon.new('http://127.0.0.1:9292')
      
      tests('connection.get').returns('GET') do
        connection.get.body
      end
      
      tests('connection.post').returns('POST') do
        connection.post.body
      end
      
    end

  end

end
