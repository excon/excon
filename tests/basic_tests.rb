Shindo.tests('Excon basics') do
  with_rackup('basic.ru') do
    basic_tests

    tests('explicit uri passed to connection') do
      tests('GET /content-length/100').returns(200) do
        connection = Excon::Connection.new({
          :host             => '127.0.0.1',
          :nonblock         => false,
          :port             => 9292,
          :scheme           => 'http',
          :ssl_verify_peer  => false
        })
        response = connection.request(:method => :get, :path => '/content-length/100')
        response[:status]
      end
    end
  end
end

Shindo.tests('Excon basics (Basic Auth Pass)') do
  with_rackup('basic_auth.ru') do
    basic_tests('http://test_user:test_password@127.0.0.1:9292')

    tests('Excon basics (Basic Auth Fail)') do
      cases = [
        ['correct user, no password', 'http://test_user@127.0.0.1:9292'],
        ['correct user, wrong password', 'http://test_user:fake_password@127.0.0.1:9292'],
        ['wrong user, correct password', 'http://fake_user:test_password@127.0.0.1:9292'],
      ]
      cases.each do |desc,url|
        tests("response.status for #{desc}").returns(401) do
          connection = Excon.new(url)
          response = connection.request(:method => :get, :path => '/content-length/100')
          response.status
        end
      end
    end
  end
end

Shindo.tests('Excon basics (ssl)') do
  with_rackup('ssl.ru') do
    basic_tests('https://127.0.0.1:9443')
  end
end

Shindo.tests('Excon basics (ssl file)',['focus']) do
  with_rackup('ssl_verify_peer.ru') do

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection = Excon::Connection.new({
        :host             => '127.0.0.1',
        :nonblock         => false,
        :port             => 8443,
        :scheme           => 'https',
        :ssl_verify_peer  => false
      })
      connection.request(:method => :get, :path => '/content-length/100')
    end

    basic_tests('https://127.0.0.1:8443',
                :client_key => File.join(File.dirname(__FILE__), 'data', 'excon.cert.key'),
                :client_cert => File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
               )

  end
end

Shindo.tests('Excon basics (ssl file paths)',['focus']) do
  with_rackup('ssl_verify_peer.ru') do

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection = Excon::Connection.new({
        :host             => '127.0.0.1',
        :nonblock         => false,
        :port             => 8443,
        :scheme           => 'https',
        :ssl_verify_peer  => false
      })
      connection.request(:method => :get, :path => '/content-length/100')
    end

    basic_tests('https://127.0.0.1:8443',
                :private_key_path => File.join(File.dirname(__FILE__), 'data', 'excon.cert.key'),
                :certificate_path => File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
               )

  end
end

Shindo.tests('Excon basics (ssl string)', ['focus']) do
  with_rackup('ssl_verify_peer.ru') do
    basic_tests('https://127.0.0.1:8443',
                :private_key => File.read(File.join(File.dirname(__FILE__), 'data', 'excon.cert.key')),
                :certificate => File.read(File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt'))
               )
  end
end

Shindo.tests('Excon basics (Unix socket)') do
  pending if RUBY_PLATFORM == 'java' # need to find suitable server for jruby

  file_name = '/tmp/unicorn.sock'
  with_unicorn('basic.ru', file_name) do
    basic_tests("unix:/", :socket => file_name)

    tests('explicit uri passed to connection') do
      tests('GET /content-length/100').returns(200) do
        connection = Excon::Connection.new({
          :socket           => file_name,
          :nonblock         => false,
          :scheme           => 'unix',
          :ssl_verify_peer  => false
        })
        response = connection.request(:method => :get, :path => '/content-length/100')
        response[:status]
      end
    end
  end
end

Shindo.tests('Excon basics (uri encoding)', ['encoding']) do
  with_rackup('basic.ru') do
    tests('encoded uri passed to connection') do
      tests('GET /echo%20dirty').returns(200) do
        connection = Excon::Connection.new({
          :host             => '127.0.0.1',
          :nonblock         => false,
          :port             => 9292,
          :scheme           => 'http',
          :ssl_verify_peer  => false
        })
        response = connection.request(:method => :get, :path => '/echo%20dirty')
        response[:status]
      end
    end

    tests('unencoded uri passed to connection') do
      tests('GET /echo dirty').returns(200) do
        connection = Excon::Connection.new({
          :host             => '127.0.0.1',
          :nonblock         => false,
          :port             => 9292,
          :scheme           => 'http',
          :ssl_verify_peer  => false
        })
        response = connection.request(:method => :get, :path => '/echo dirty')
        response[:status]
      end
    end
  end
end

Shindo.tests('Excon basics (reusable local port)') do
  with_rackup('basic.ru') do
    connection = Excon.new("http://127.0.0.1:9292/echo",
                           :reuseaddr => true, # enable address and port reuse
                           :persistent => true # keep the socket open
                           )
    response = connection.get

    tests('has a local port').returns(true) do
      response.local_port.to_s =~ /\d{4,5}/ ? true : false
    end

    tests('local port can be re-bound').returns('x' * 10) do
      # create a socket with address/port reuse enabled
      s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      s.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      if defined?(Socket::SO_REUSEPORT)
        s.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)
      end

      # bind to the same local port and address used in the get above (won't work without reuse options on both sockets)
      s.bind(Socket.pack_sockaddr_in(response.local_port, response.local_address))

      # connect to the server on a different address than was used for the initial connection to avoid duplicate 5-tuples of: {protcol, src_port, src_addr, dst_port, dst_addr}
      ip = Socket.ip_address_list.detect{|a|
        a.ipv4? &&
        (a.ipv4_private? || a.ipv4_loopback?) &&
        a.ip_address != '127.0.0.1'
      }.ip_address rescue '127.0.0.1'
      s.connect(Socket.pack_sockaddr_in(9292, ip))

      # send the request
      s.print "GET /content-length/10 HTTP/1.0\r\n\r\n"

      # read the response and return the body
      response = s.read
      headers, body = response.split("\r\n\r\n", 2)

      # close both the sockets
      s.close
      connection.reset

      body
    end
  end
end
