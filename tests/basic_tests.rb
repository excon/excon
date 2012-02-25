with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    basic_tests
  end
end

with_rackup('basic_auth.ru') do
  Shindo.tests('Excon basics (Basic Auth Pass)') do
    basic_tests('http://test_user:test_password@127.0.0.1:9292')
  end

  Shindo.tests('Excon basics (Basic Auth Fail)') do
    cases = [
      ['correct user, no password', 'http://test_user@127.0.0.1:9292'],
      ['correct user, wrong password', 'http://test_user:fake_password@127.0.0.1:9292'],
      ['wrong user, correct password', 'http://fake_user:test_password@127.0.0.1:9292'],
    ]
    cases.each do |desc,url|
      connection = Excon.new(url)
      response = connection.request(:method => :get, :path => '/content-length/100')

      tests("response.status for #{desc}").returns(401) do
        response.status
      end

    end
  end
end

with_rackup('ssl.ru') do
  Shindo.tests('Excon basics (ssl)') do
    basic_tests('https://127.0.0.1:9443')
  end
end
