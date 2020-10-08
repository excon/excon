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
        !r.match(/two:/).nil?
      end

    end

    tests('header order') do
      tests('host is the first sent header by default').returns('host: localhost:9292') do
        response = Excon.post('http://localhost:9292/')

        response.body.lines.first.chomp
      end
    end

  end

end
