require 'json'

Shindo.tests('Excon basics') do
  env_init

  with_rackup('basic.ru') do
    basic_tests

    tests('explicit uri passed to connection') do
      tests('GET /content-length/100').returns(200) do
        connection = Excon::Connection.new({
          :host             => '127.0.0.1',
          :hostname         => '127.0.0.1',
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

Shindo.tests('Excon streaming basics') do
  tests('http') do
    with_puma('streaming.ru') do
      streaming_tests('http')
    end
  end
  tests('https') do
    with_ssl_streaming(9292, STREAMING_PIECES, STREAMING_TIMEOUT) do
      streaming_tests('https')
    end
  end
end

Shindo.tests('Excon basics (Basic Auth Pass)') do
  with_rackup('basic_auth.ru') do
    basic_tests('http://test_user:test_password@127.0.0.1:9292')
    user, pass, uri = ['test_user', 'test_password', 'http://127.0.0.1:9292'].map(&:freeze)

    tests('with frozen args').returns(200) do
      connection = Excon.new(uri, :method => :get, :password => pass, :path => '/content-length/100', :user => user)
      response = connection.request
      response.status
    end

    tests('with user/pass on request').returns(200) do
      connection = Excon.new(uri, :method => :get, :path => '/content-length/100')
      response = connection.request(:user => user, :password => pass)
      response.status
    end

    tests('with user/pass on connection and request').returns(200) do
      connection = Excon.new(uri, :method => :get, :password => 'incorrect_password', :path => '/content-length/100', :user => 'incorrect_user')
      response = connection.request(user: user, password: pass)
      response.status
    end
  end
end

Shindo.tests('Excon basics (Basic Auth Fail)') do
  with_rackup('basic_auth.ru') do
    cases = [
      ['correct user, no password', 'http://test_user@127.0.0.1:9292'],
      ['correct user, wrong password', 'http://test_user:fake_password@127.0.0.1:9292'],
      ['wrong user, correct password', 'http://fake_user:test_password@127.0.0.1:9292']
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

Shindo.tests('Excon basics (ssl)') do
  with_rackup('ssl.ru') do
    basic_tests('https://127.0.0.1:9443')
  end
end

Shindo.tests('Excon basics verify_hostname (ssl)') do
  with_rackup('ssl.ru') do
    connection = nil
    test do
      ssl_ca_file = File.join(File.dirname(__FILE__), 'data', '127.0.0.1.cert.crt')
      connection = Excon.new('https://127.0.0.1:9443', :ssl_verify_peer => true, :ssl_ca_file => ssl_ca_file, :ssl_verify_hostname => true )
      true
    end

    tests('response.status').returns(200) do
      response = connection.request(:method => :get, :path => '/content-length/100')

      response.status
    end
  end
end

Shindo.tests('Excon ssl verify peer (ssl)') do
  with_rackup('ssl.ru') do
    connection = nil
    test do
      ssl_ca_file = File.join(File.dirname(__FILE__), 'data', '127.0.0.1.cert.crt')
      connection = Excon.new('https://127.0.0.1:9443', :ssl_verify_peer => true, :ssl_ca_file => ssl_ca_file )
      true
    end

    tests('response.status').returns(200) do
      response = connection.request(:method => :get, :path => '/content-length/100')

      response.status
    end
  end

  with_rackup('ssl_mismatched_cn.ru') do
    connection = nil
    test do
      ssl_ca_file = File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
      connection = Excon.new('https://127.0.0.1:9443', :ssl_verify_peer => true, :ssl_ca_file => ssl_ca_file, :ssl_verify_peer_host => 'excon' )
      true
    end

    tests('response.status').returns(200) do
      response = connection.request(:method => :get, :path => '/content-length/100')

      response.status
    end
  end

  with_rackup('ssl_sni_verify_host.ru') do
    connection = nil
    test do
      ssl_ca_file = File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
      connection = Excon.new('https://127.0.0.1:9443', :ssl_verify_peer => true, :ssl_ca_file => ssl_ca_file, :ssl_verify_peer_host => 'excon' )
      true
    end

    tests('response.status').returns(200) do
      response = connection.request(:method => :get, :path => '/content-length/100')

      response.status
    end
  end
end

Shindo.tests('Excon ssl verify peer (ssl cert store)') do
  with_rackup('ssl.ru') do
    connection = nil
    test do
      ssl_ca_cert = File.read(File.join(File.dirname(__FILE__), 'data', '127.0.0.1.cert.crt'))
      ssl_cert_store = OpenSSL::X509::Store.new
      ssl_cert_store.add_cert OpenSSL::X509::Certificate.new ssl_ca_cert
      connection = Excon.new('https://127.0.0.1:9443', :ssl_verify_peer => true, :ssl_cert_store => ssl_cert_store )
      true
    end

    tests('response.status').returns(200) do
      response = connection.request(:method => :get, :path => '/content-length/100')

      response.status
    end
  end
end

Shindo.tests('Excon basics (ssl file)',['focus']) do
  with_rackup('ssl_verify_peer.ru') do

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection = Excon::Connection.new({
        :host             => '127.0.0.1',
        :hostname         => '127.0.0.1',
        :nonblock         => false,
        :port             => 8443,
        :scheme           => 'https',
        :ssl_verify_peer  => false
      })
      connection.request(:method => :get, :path => '/content-length/100')
    end

    cert_key_path = File.join(File.dirname(__FILE__), 'data', 'excon.cert.key')
    cert_crt_path = File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt')
    basic_tests('https://127.0.0.1:8443', client_key: cert_key_path, client_cert: cert_crt_path)

    cert_key_data = File.read cert_key_path
    cert_crt_data = File.read cert_crt_path
    basic_tests('https://127.0.0.1:8443', client_key_data: cert_key_data, client_cert_data: cert_crt_data)
  end
end

Shindo.tests('Excon basics (ssl chain)',['focus']) do
  with_rackup('ssl_verify_peer_with_chain.ru') do

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection = Excon::Connection.new({
        :host             => '127.0.0.1',
        :hostname         => '127.0.0.1',
        :nonblock         => false,
        :port             => 8443,
        :scheme           => 'https',
        :ssl_verify_peer  => false
      })
      connection.request(:method => :get, :path => '/content-length/100')
    end

    cert_key_path = File.join(File.dirname(__FILE__), 'data', 'excon_client.cert.key')
    cert_crt_path = File.join(File.dirname(__FILE__), 'data', 'excon_client.cert.crt')
    chain_crt_path = File.join(File.dirname(__FILE__), 'data', 'excon_intermediate.cert.crt')
    basic_tests('https://127.0.0.1:8443', client_key: cert_key_path, client_cert: cert_crt_path, client_chain: chain_crt_path)

    cert_key_data = File.read cert_key_path
    cert_crt_data = File.read cert_crt_path
    chain_crt_data = File.read chain_crt_path
    basic_tests('https://127.0.0.1:8443', client_key_data: cert_key_data, client_cert_data: cert_crt_data, client_chain_data: chain_crt_data)
  end
end

Shindo.tests('Excon basics (ssl file paths)',['focus']) do
  with_rackup('ssl_verify_peer.ru') do

    tests('GET /content-length/100').raises(Excon::Errors::SocketError) do
      connection = Excon::Connection.new({
        :host             => '127.0.0.1',
        :hostname         => '127.0.0.1',
        :nonblock         => false,
        :port             => 8443,
        :scheme           => 'https',
        :ssl_verify_peer  => false
      })
      connection.request(:method => :get, :path => '/content-length/100')
    end

    basic_tests(
      'https://127.0.0.1:8443',
      client_cert: File.join(File.dirname(__FILE__), 'data', 'excon.cert.crt'),
      client_key: File.join(File.dirname(__FILE__), 'data', 'excon.cert.key')
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
  file_name = '/tmp/puma.sock'
  with_puma('basic.ru', 'unix://'+file_name) do
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

    tests('http Host header is empty') do
      tests('GET /headers').returns("") do
        connection = Excon::Connection.new({
          :socket           => file_name,
          :nonblock         => false,
          :scheme           => 'unix',
          :ssl_verify_peer  => false
        })
        response = connection.request(:method => :get, :path => '/headers')
        JSON.parse(response.body)['HTTP_HOST']
      end
    end
  end
end

Shindo.tests('Excon basics (reusable local port)') do
  class CustomSocket < Socket
    def initialize
      super(AF_INET, SOCK_STREAM, 0)
      setsockopt(SOL_SOCKET, SO_REUSEADDR, true)
      if defined?(SO_REUSEPORT)
        setsockopt(SOL_SOCKET, SO_REUSEPORT, true)
      end
    end

    def bind(address, port)
      super(Socket.pack_sockaddr_in(port, address))
    end

    def connect(address, port)
      super(Socket.pack_sockaddr_in(port, address))
    end

    def http_get(path)
      print "GET /content-length/10 HTTP/1.0\r\n\r\n"
      read.split("\r\n\r\n", 2)[1]
    end

    def self.ip_address_list
      if Socket.respond_to?(:ip_address_list)
        Socket.ip_address_list.select(&:ipv4?).map(&:ip_address)
      else
        `ifconfig`.scan(/inet.*?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/).flatten
      end
    end

    def self.find_alternate_ip(ip)
      ip_address_list.detect {|a| a != ip }
    end
  end

  with_rackup('basic.ru', '0.0.0.0') do
    connection = Excon.new("http://127.0.0.1:9292/echo",
                           :reuseaddr => true, # enable address and port reuse
                           :persistent => true # keep the socket open
                           )
    response = connection.get

    tests('has a local port').returns(true) do
      response.local_port.to_s.match?(/\d{4,5}/)
    end

    tests('local port can be re-bound').returns('x' * 10) do
      # skip if no alternatives, ie in a container with disabled networking
      pending unless CustomSocket.find_alternate_ip(response.local_address)

      # create a socket with address/port reuse enabled
      s = CustomSocket.new

      # bind to the same local port and address used in the get above (won't work without reuse options on both sockets)
      s.bind(response.local_address, response.local_port)

      # connect to the server on a different address than was used for the initial connection to avoid duplicate 5-tuples of: {protcol, src_port, src_addr, dst_port, dst_addr}
      s.connect(CustomSocket.find_alternate_ip(response.local_address), 9292)

      # send the request
      body = s.http_get("/content-length/10")

      # close both the sockets
      s.close
      connection.reset

      body
    end
  end
end
