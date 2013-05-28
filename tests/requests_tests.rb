with_rackup('basic.ru') do
  Shindo.tests('requests should succeed') do

    connection = Excon.new('http://127.0.0.1:9292')

    tests('HEAD /content-length/100, GET /content-length/100') do
      responses = connection.requests([
        {:method => :head, :path => '/content-length/100'},
        {:method => :get, :path => '/content-length/100'}
      ])

      tests('head body is empty').returns('') do
        responses.first.body
      end

      tests('head content length is 100').returns('100') do
        responses.first.headers['Content-Length']
      end

      tests('get body is non-empty').returns('x' * 100) do
        responses.last.body
      end

      tests('get content length is 100').returns('100') do
        responses.last.headers['Content-Length']
      end

    end

  end

  Shindo.tests('requests should succeed with tcp_nodelay') do

    connection = Excon.new('http://127.0.0.1:9292', :tcp_nodelay => true)

    tests('GET /content-length/100') do
      responses = connection.requests([
        {:method => :get, :path => '/content-length/100'}
      ])

      tests('get content length is 100').returns('100') do
        responses.last.headers['Content-Length']
      end
    end
  end
end
