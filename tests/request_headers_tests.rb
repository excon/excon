Shindo.tests('Excon request methods') do

  with_rackup('request_headers.ru') do

    tests 'empty headers sent' do

      test('Excon.post') do
        headers = {
          :one => 1,
          :two => nil,
          :three => 3,
        }
        r = Excon.post('http://localhost:9292', :headers => headers).body
        r.include?('two:')
      end

    end

    tests('header order') do
      tests('host is the first sent header by default').returns('host: localhost:9292') do
        response = Excon.post('http://localhost:9292/')

        response.body.lines.first.chomp
      end
    end

    tests('default headers') do
      tests('are overridden regardless of casing').returns(['accept: application/json']) do
        connection = Excon.new('http://127.0.0.1:9292')
        response = connection.post(headers: { 'accept' => 'application/json' })

        response.body.lines.map(&:chomp).grep(/\Aaccept:/)
      end
    end

  end

end
