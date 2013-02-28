with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    basic_tests
  end

  Shindo.tests('explicit uri passed to connection') do
    connection = Excon::Connection.new({
      :host             => '127.0.0.1',
      :nonblock         => false,
      :port             => 9292,
      :scheme           => 'http',
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

with_rackup('ssl_verify_peer.ru') do
  Shindo.tests('Excon basics (ssl)',['focus']) do
    connection = Excon::Connection.new({
      :host             => '127.0.0.1',
      :nonblock         => false,
      :port             => 8443,
      :scheme           => 'https',
      :ssl_verify_peer  => false
    })

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection.request(:method => :get, :path => '/content-length/100')
    end

    basic_tests('https://127.0.0.1:8443',
                :client_key => File.join(File.dirname(__FILE__), 'data', 'excon.cert.key'),
                :client_cert => File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
               )
  end
end
