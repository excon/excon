Shindo.tests('Excon bad server interaction') do

  with_server('bad') do

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
            block = lambda {|chunk, remaining, total| body << chunk }

            connection.request(:method => :get, :path => '/eof/no_content_length_and_no_chunking', &block)

            body
          end
        end

      end

    end

  end

end
