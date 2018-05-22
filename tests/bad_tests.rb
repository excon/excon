Shindo.tests('Excon bad server interaction') do

  with_server('bad') do

    tests('prevents header splitting').returns(true) do
      connection = Excon.new('http://127.0.0.1:9292')
      request = <<-BODY
GET /echo HTTP/1.1\r
User-Agent: excon/0.62.0\r
Foo: bar Baz: qux\r
Host: 127.0.0.1:9292\r
\r
BODY
      response = connection.request(
        headers: { Foo: "bar\r\nBaz: qux" },
        method:  :get,
        path: '/echo'
      )
      response.body == request
    end

    tests('bad server: causes EOFError') do

      tests('with no content length and no chunking') do
        tests('without a block') do
          tests('response.body').returns('hello') do
            connection = Excon.new('http://127.0.0.1:9292')

            connection.request(:method => :get, :path => '/eof/no_content_length_and_no_chunking').body
          end
        end

        tests('with a block') do
          tests('body from chunks').returns('hello') do
            connection = Excon.new('http://127.0.0.1:9292')

            body = ""
            response_block = lambda {|chunk, remaining, total| body << chunk }

            connection.request(:method => :get, :path => '/eof/no_content_length_and_no_chunking', :response_block => response_block)

            body
          end
        end

      end

    end

  end

  with_server('eof') do

    tests('eof server: causes EOFError') do

      tests('request').raises(Excon::Errors::SocketError) do
        Excon.get('http://127.0.0.1:9292/eof')
      end

    end

  end

end
