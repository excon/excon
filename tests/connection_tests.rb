Shindo.tests('Excon Connection') do
  env_init

  with_rackup('basic.ru') do
    tests('#socket connects, sets data[:remote_ip]').returns('127.0.0.1') do
      connection = Excon::Connection.new(
        :host             => '127.0.0.1',
        :hostname         => '127.0.0.1',
        :nonblock         => false,
        :port             => 9292,
        :scheme           => 'http',
        :ssl_verify_peer  => false
      )
      connection.send(:socket) # creates/connects socket
      connection.data[:remote_ip]
    end

    tests("persistent connections") do
      connection = Excon.new('http://127.0.0.1:9292', persistent: true)

      response_body = connection.request(path: '/foo', method: 'get').body
      test("successful uninterrupted request") do
        connection.request(path: '/foo', method: 'get').body == 'foo'
      end

      begin
        # simulate an interrupted connection which leaves data behind
        Timeout::timeout(0.0000000001) do
          connection.request(path: '/foo', method: 'get')
        end
      rescue Timeout::Error
        nil
      end

      test("resets connection after interrupt") do
        response = connection.request(path: '/bar', method: 'get')
        response.body == 'bar'
      end

      if ::Process.respond_to?(:fork)
        connection_id = connection.send(:socket).object_id
        test("fork safety") do
          read, write = IO.pipe
          pid = fork do
            connection_id = connection.send(:socket).object_id
            write.write(Marshal.dump(connection_id))
            write.close
            exit!(0)
          end
          Process.waitpid(pid)
          child_connection_id = Marshal.load(read)
          child_connection_id != connection_id
        end
      end
    end
  end

  tests("inspect redaction") do
    cases = [
      ['user & pass', 'http://user1:pass1@foo.com/', 'Basic dXNlcjE6cGFzczE='],
      ['email & pass', 'http://foo%40bar.com:pass1@foo.com/', 'Basic Zm9vQGJhci5jb206cGFzczE='],
      ['user no pass', 'http://three_user@foo.com/', 'Basic dGhyZWVfdXNlcjo='],
      ['pass no user', 'http://:derppass@foo.com/', 'Basic OmRlcnBwYXNz']
    ]
    cases.each do |desc,url,auth_header|
      conn = Excon.new(url, :proxy => url)

      test("authorization/proxy-authorization headers concealed for #{desc}") do
        !conn.inspect.include?(auth_header)
      end

      if conn.data[:password]
        test("password param concealed for #{desc}") do
          !conn.inspect.include?(conn.data[:password])
        end

        test("password param not mutated for #{desc}") do
          conn.data[:password] == URI.parse(url).password
        end
      end

      if conn.data[:proxy] && conn.data[:proxy][:password]
        test("proxy password param concealed for proxy: #{desc}") do
          !conn.inspect.include?(conn.data[:proxy][:password])
        end

        test("proxy password param not mutated for proxy: #{desc}") do
          conn.data[:proxy][:password] == URI.parse(url).password
        end
      end
    end
  end

  env_restore
end
