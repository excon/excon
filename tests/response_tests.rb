Shindo.tests('Excon Response Parsing') do
  env_init

  with_server('good') do

    tests('responses with chunked transfer-encoding') do

      tests('simple response').returns('hello world') do
        Excon.get('http://127.0.0.1:9292/chunked/simple').body
      end

      tests('with :response_block') do

        tests('simple response').
              returns([['hello ', nil, nil], ['world', nil, nil]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/chunked/simple',
                      :response_block => block,
                      :chunk_size => 5) # not used
          end
        end

        tests('with expected response status').
              returns([['hello ', nil, nil], ['world', nil, nil]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/chunked/simple',
                      :response_block => block,
                      :expects => 200)
          end
        end

        tests('with unexpected response status').returns('hello world') do
          begin
            Excon.get('http://127.0.0.1:9292/chunked/simple',
                      :response_block => Proc.new { raise 'test failed' },
                      :expects => 500)
          rescue Excon::Errors::HTTPStatusError => err
            err.response[:body]
          end
        end

      end

      tests('merges trailers into headers').
          returns('one, two, three, four, five, six') do
        Excon.get('http://127.0.0.1:9292/chunked/trailers').headers['Test-Header']
      end

      tests("removes 'chunked' from Transfer-Encoding").returns('') do
        Excon.get('http://127.0.0.1:9292/chunked/simple').headers['Transfer-Encoding']
      end

    end

    tests('responses with content-length') do

      tests('simple response').returns('hello world') do
        Excon.get('http://127.0.0.1:9292/content-length/simple').body
      end

      tests('with :response_block') do

        tests('simple response').
              returns([['hello', 6, 11], [' worl', 1, 11], ['d', 0, 11]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/content-length/simple',
                      :response_block => block,
                      :chunk_size => 5)
          end
        end

        tests('with expected response status').
              returns([['hello', 6, 11], [' worl', 1, 11], ['d', 0, 11]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/content-length/simple',
                      :response_block => block,
                      :chunk_size => 5,
                      :expects => 200)
          end
        end

        tests('with unexpected response status').returns('hello world') do
          begin
            Excon.get('http://127.0.0.1:9292/content-length/simple',
                      :response_block => Proc.new { raise 'test failed' },
                      :chunk_size => 5,
                      :expects => 500)
          rescue Excon::Errors::HTTPStatusError => err
            err.response[:body]
          end
        end

      end

    end

    tests('responses with unknown length') do

      tests('simple response').returns('hello world') do
        Excon.get('http://127.0.0.1:9292/unknown/simple').body
      end

      tests('with :response_block') do

        tests('simple response').
              returns([['hello', nil, nil], [' worl', nil, nil], ['d', nil, nil]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/unknown/simple',
                      :response_block => block,
                      :chunk_size => 5)
          end
        end

        tests('with expected response status').
              returns([['hello', nil, nil], [' worl', nil, nil], ['d', nil, nil]]) do
          capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/unknown/simple',
                      :response_block => block,
                      :chunk_size => 5,
                      :expects => 200)
          end
        end

        tests('with unexpected response status').returns('hello world') do
          begin
            Excon.get('http://127.0.0.1:9292/unknown/simple',
                      :response_block => Proc.new { raise 'test failed' },
                      :chunk_size => 5,
                      :expects => 500)
          rescue Excon::Errors::HTTPStatusError => err
            err.response[:body]
          end
        end

      end

    end

    tests('header continuation') do

      tests('proper continuation').returns('one, two, three, four, five, six') do
        resp = Excon.get('http://127.0.0.1:9292/unknown/header_continuation')
        resp.headers['Test-Header']
      end

      tests('malformed header').raises(Excon::Errors::SocketError) do
        Excon.get('http://127.0.0.1:9292/bad/malformed_header')
      end

      tests('malformed header continuation').raises(Excon::Errors::SocketError) do
        Excon.get('http://127.0.0.1:9292/bad/malformed_header_continuation')
      end

    end

    tests('Transfer-Encoding') do

      tests('used with chunked response') do
        resp = nil

        tests('server sent transfer-encoding').returns('gzip, chunked') do
          resp = Excon.post(
            'http://127.0.0.1:9292/echo/transfer-encoded/chunked',
            :body => 'hello world'
          )

          resp[:headers]['Transfer-Encoding-Sent']
        end

        tests('processed encodings removed from header').returns('') do
          resp[:headers]['Transfer-Encoding']
        end

        tests('response body decompressed').returns('hello world') do
          resp[:body]
        end
      end

      tests('used with non-chunked response') do
        resp = nil

        tests('server sent transfer-encoding').returns('gzip') do
          resp = Excon.post(
            'http://127.0.0.1:9292/echo/transfer-encoded',
            :body => 'hello world'
          )

          resp[:headers]['Transfer-Encoding-Sent']
        end

        tests('processed encoding removed from header').returns('') do
          resp[:headers]['Transfer-Encoding']
        end

        tests('response body decompressed').returns('hello world') do
          resp[:body]
        end
      end

      # sends TE header without gzip/deflate accepted (see requests_tests)
      tests('with a :response_block') do
        captures = nil

        tests('server does not compress').returns('chunked') do
          resp = nil
          captures = capture_response_block do |block|
            resp = Excon.post('http://127.0.0.1:9292/echo/transfer-encoded/chunked',
                              :body => 'hello world',
                              :response_block => block)
          end

          resp[:headers]['Transfer-Encoding-Sent']
        end

        tests('block receives uncompressed response').returns('hello world') do
          captures.map {|capture| capture[0] }.join
        end

      end

    end

  end

  env_restore
end
