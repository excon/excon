Shindo.tests('requests should succeed') do
  with_rackup('basic.ru') do

    tests('HEAD /content-length/100, GET /content-length/100') do

      connection = Excon.new('http://127.0.0.1:9292')
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

    tests('requests should succeed with tcp_nodelay') do

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

  with_server('good') do

    tests('sets transfer-coding and connection options') do

      tests('without a :response_block') do
        request = Marshal.load(
          Excon.get('http://127.0.0.1:9292/echo/request').body
        )
        returns('trailers, deflate, gzip') { request[:headers]['TE'] }
        returns('TE') { request[:headers]['Connection'] }
      end

      tests('with a :response_block') do
        captures = capture_response_block do |block|
          Excon.get('http://127.0.0.1:9292/echo/request',
                    :response_block => block)
        end
        data = captures.map {|capture| capture[0] }.join
        request = Marshal.load(data)

        returns('trailers') { request[:headers]['TE'] }
        returns('TE') { request[:headers]['Connection'] }
      end

    end

  end
end
