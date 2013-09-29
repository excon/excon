file_name = '/tmp/unicorn.sock'
with_unicorn_rackup('basic.ru', file_name) do
  Shindo.tests('Excon basics') do
    [false, true].each do |nonblock|
      reset_connection = true
      options = {:ssl_verify_peer => false, :nonblock => nonblock }
      connection = Excon.new("unix://#{file_name}", options)

      tests("nonblock => #{nonblock}") do

        tests('GET /content-length/100') do
          response = connection.request(:method => :get, :path => '/content-length/100')

          tests('response.status').returns(200) do
            response.status
          end

          tests('response[:status]').returns(200) do
            response[:status]
          end

          tests("response.headers['Content-Length']").returns('100') do
            response.headers['Content-Length']
          end

          tests("response.headers['Content-Type']").returns('text/html;charset=utf-8') do
            response.headers['Content-Type']
          end

          test("Time.parse(response.headers['Date']).is_a?(Time)") do
            Time.parse(response.headers['Date']).is_a?(Time)
          end

          tests("response.headers['Custom']").returns("Foo: bar") do
            response.headers['Custom']
          end

          tests("response.body").returns('x' * 100) do
            response.body
          end

          tests("deprecated block usage").returns(['x' * 100, 0, 100]) do
            data = []
            connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_length, total_length|
              data = [chunk, remaining_length, total_length]
            end
            data
          end

          tests("response_block usage").returns(['x' * 100, 0, 100]) do
            data = []
            response_block = lambda do |chunk, remaining_length, total_length|
              data = [chunk, remaining_length, total_length]
            end
            connection.request(:method => :get, :path => '/content-length/100', :response_block => response_block)
            data
          end

        end

        tests('POST /body-sink') do

          tests('response.body').returns("5000000") do
            if reset_connection && !nonblock
              connection.reset
            end
            response = connection.request(:method => :post, :path => '/body-sink', :headers => { 'Content-Type' => 'text/plain' }, :body => 'x' * 5_000_000)
            response.body
          end

          tests('empty body').returns('0') do
            response = connection.request(:method => :post, :path => '/body-sink', :headers => { 'Content-Type' => 'text/plain' }, :body => '')
            response.body
          end

        end

        tests('POST /echo') do

          tests('with file').returns('x' * 100 + "\n") do
            file_path = File.join(File.dirname(__FILE__), "data", "xs")
            response = connection.request(:method => :post, :path => '/echo', :body => File.open(file_path))
            response.body
          end

          tests('without request_block').returns('x' * 100) do
            response = connection.request(:method => :post, :path => '/echo', :body => 'x' * 100)
            response.body
          end

          tests('with request_block').returns('x' * 100) do
            data = ['x'] * 100
            request_block = lambda do
              data.shift.to_s
            end
            response = connection.request(:method => :post, :path => '/echo', :request_block => request_block)
            response.body
          end

          tests('with multi-byte strings') do
            body = "\xC3\xBC" * 100
            headers = { 'Custom' => body.dup }
            if RUBY_VERSION >= '1.9'
              body.force_encoding('BINARY')
              headers['Custom'].force_encoding('UTF-8')
            end

            returns(body, 'properly concatenates request+headers and body') do
              response = connection.request(:method => :post, :path => '/echo', :headers => headers, :body => body)
              response.body
            end
          end

        end

        tests('PUT /echo') do

          tests('with file').returns('x' * 100 + "\n") do
            file_path = File.join(File.dirname(__FILE__), "data", "xs")
            response = connection.request(:method => :put, :path => '/echo', :body => File.open(file_path))
            response.body
          end

          tests('without request_block').returns('x' * 100) do
            response = connection.request(:method => :put, :path => '/echo', :body => 'x' * 100)
            response.body
          end

          tests('request_block usage').returns('x' * 100) do
            data = ['x'] * 100
            request_block = lambda do
              data.shift.to_s
            end
            response = connection.request(:method => :put, :path => '/echo', :request_block => request_block)
            response.body
          end

          tests('with multi-byte strings') do
            body = "\xC3\xBC" * 100
            headers = { 'Custom' => body.dup }
            if RUBY_VERSION >= '1.9'
              body.force_encoding('BINARY')
              headers['Custom'].force_encoding('UTF-8')
            end

            returns(body, 'properly concatenates request+headers and body') do
              response = connection.request(:method => :put, :path => '/echo', :headers => headers, :body => body)
              response.body
            end
          end

        end

      end
    end
  end

  Shindo.tests('explicit uri passed to connection') do
    connection = Excon::Connection.new({
      :path             => file_name,
      :nonblock         => false,
      :scheme           => 'unix',
      :ssl_verify_peer  => false
    })

    tests('GET /content-length/100') do
      response = connection.request(:method => :get, :path => '/content-length/100')

      tests('response[:status]').returns(200) do
        response[:status]
      end
    end
  end
end


