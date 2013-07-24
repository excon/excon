Shindo.tests('Excon proxy support') do
  env_init

  tests('proxy configuration') do

    tests('no proxy') do
      connection = Excon.new('http://foo.com')

      tests('connection.data[:proxy]').returns(nil) do
        connection.data[:proxy]
      end
    end

    tests('with fully-specified proxy: https://myproxy.net:8080') do
      connection = Excon.new('http://foo.com', :proxy => 'https://myproxy.net:8080')

      tests('connection.data[:proxy][:host]').returns('myproxy.net') do
        connection.data[:proxy][:host]
      end

      tests('connection.data[:proxy][:port]').returns(8080) do
        connection.data[:proxy][:port]
      end

      tests('connection.data[:proxy][:scheme]').returns('https') do
        connection.data[:proxy][:scheme]
      end
    end

    def env_proxy_tests(env)
      env_init(env)

      tests('an http connection') do
        connection = Excon.new('http://foo.com')

        tests('connection.data[:proxy][:host]').returns('myproxy') do
          connection.data[:proxy][:host]
        end

        tests('connection.data[:proxy][:port]').returns(8080) do
          connection.data[:proxy][:port]
        end

        tests('connection.data[:proxy][:scheme]').returns('http') do
          connection.data[:proxy][:scheme]
        end
      end

      tests('an https connection') do
        connection = Excon.new('https://secret.com')

        tests('connection.data[:proxy][:host]').returns('mysecureproxy') do
          connection.data[:proxy][:host]
        end

        tests('connection.data[:proxy][:port]').returns(8081) do
          connection.data[:proxy][:port]
        end

        tests('connection.data[:proxy][:scheme]').returns('http') do
          connection.data[:proxy][:scheme]
        end
      end

      tests('http proxy from the environment overrides config') do
        connection = Excon.new('http://foo.com', :proxy => 'http://hard.coded.proxy:6666')

        tests('connection.data[:proxy][:host]').returns('myproxy') do
          connection.data[:proxy][:host]
        end

        tests('connection.data[:proxy][:port]').returns(8080) do
          connection.data[:proxy][:port]
        end
      end

      tests('an http connection in no_proxy') do
        connection = Excon.new('http://somesubdomain.noproxy')

        tests('connection.data[:proxy]').returns(nil) do 
          connection.data[:proxy]
        end
      end

      tests('an http connection not completely matching no_proxy') do
        connection = Excon.new('http://noproxy2')

        tests('connection.data[:proxy][:host]').returns('myproxy') do
          connection.data[:proxy][:host]
        end
      end

      tests('an http connection with subdomain in no_proxy') do
        connection = Excon.new('http://a.subdomain.noproxy2')

        tests('connection.data[:proxy]').returns(nil) do
          connection.data[:proxy]
        end
      end

      env_restore
    end

    tests('with complete proxy config from the environment') do
      env = {
        'http_proxy' => 'http://myproxy:8080',
        'https_proxy' => 'http://mysecureproxy:8081',
        'no_proxy' => 'noproxy, subdomain.noproxy2'
      }
      tests('lowercase') { env_proxy_tests(env) }
      upperenv = {}
      env.each do |k, v|
        upperenv[k.upcase] = v
      end
      tests('uppercase') { env_proxy_tests(upperenv) }
    end

    tests('with only http_proxy config from the environment') do
      env_init({'http_proxy' => 'http://myproxy:8080' })

      tests('an https connection') do
        connection = Excon.new('https://secret.com')

        tests('connection.data[:proxy][:host]').returns('myproxy') do
          connection.data[:proxy][:host]
        end

        tests('connection.data[:proxy][:port]').returns(8080) do
          connection.data[:proxy][:port]
        end

        tests('connection.data[:proxy][:scheme]').returns('http') do
          connection.data[:proxy][:scheme]
        end
      end

      env_restore
    end

  end

  with_rackup('proxy.ru') do

    tests('http proxying: http://foo.com:8080') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://127.0.0.1:9292')
      response = connection.request(:method => :get, :path => '/bar', :query => {:alpha => 'kappa'})

      tests('response.status').returns(200) do
        response.status
      end

      # must be absolute form for proxy requests
      tests('sent Request URI').returns('http://foo.com:8080/bar?alpha=kappa') do
        response.headers['Sent-Request-Uri']
      end

      tests('sent Sent-Host header').returns('foo.com:8080') do
        response.headers['Sent-Host']
      end

      tests('sent Proxy-Connection header').returns('Keep-Alive') do
        response.headers['Sent-Proxy-Connection']
      end

      tests('response.body (proxied content)').returns('proxied content') do
        response.body
      end
    end

    tests('http proxying: http://user:pass@foo.com:8080') do
      connection = Excon.new('http://foo.com:8080', :proxy => 'http://user:pass@127.0.0.1:9292')
      response = connection.request(:method => :get, :path => '/bar', :query => {:alpha => 'kappa'})

      tests('response.status').returns(200) do
        response.status
      end

      # must be absolute form for proxy requests
      tests('sent Request URI').returns('http://foo.com:8080/bar?alpha=kappa') do
        response.headers['Sent-Request-Uri']
      end

      tests('sent Host header').returns('foo.com:8080') do
        response.headers['Sent-Host']
      end

      tests('sent Proxy-Connection header').returns('Keep-Alive') do
        response.headers['Sent-Proxy-Connection']
      end

      tests('response.body (proxied content)').returns('proxied content') do
        response.body
      end
    end

  end

  env_restore
end
