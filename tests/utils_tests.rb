Shindo.tests('Excon::Utils') do

  tests('#connection_uri') do

    expected_uri = 'unix:///tmp/some.sock'
    tests('using UNIX scheme').returns(expected_uri) do
      connection = Excon.new('unix:///some/path', :socket => '/tmp/some.sock')
      Excon::Utils.connection_uri(connection.data)
    end

    tests('using HTTP scheme') do

      expected_uri = 'http://foo.com'
      tests('without default port').returns(expected_uri) do
        connection = Excon.new('http://foo.com/some/path')
        Excon::Utils.connection_uri(connection.data)
      end

      expected_uri = 'http://foo.com:80'
      tests('without default port').returns(expected_uri) do
        connection = Excon.new('http://foo.com/some/path', :include_default_port => true)
        Excon::Utils.connection_uri(connection.data)
      end

    end

  end

  tests('#request_uri') do

    tests('using UNIX scheme') do

      expected_uri = 'unix:///tmp/some.sock/some/path'
      tests('without query').returns(expected_uri) do
        connection = Excon.new('unix:/', :socket => '/tmp/some.sock')
        params = { :path => '/some/path' }
        Excon::Utils.request_uri(connection.data.merge(params))
      end

      expected_uri = 'unix:///tmp/some.sock/some/path?bar=that&foo=this'
      tests('with query').returns(expected_uri) do
        connection = Excon.new('unix:/', :socket => '/tmp/some.sock')
        params = { :path => '/some/path', :query => { :foo => 'this', :bar => 'that' } }
        Excon::Utils.request_uri(connection.data.merge(params))
      end

    end

    tests('using HTTP scheme') do

      expected_uri = 'http://foo.com/some/path'
      tests('without query').returns(expected_uri) do
        connection = Excon.new('http://foo.com')
        params = { :path => '/some/path' }
        Excon::Utils.request_uri(connection.data.merge(params))
      end

      expected_uri = 'http://foo.com/some/path?bar=that&foo=this'
      tests('with query').returns(expected_uri) do
        connection = Excon.new('http://foo.com')
        params = { :path => '/some/path', :query => { :foo => 'this', :bar => 'that' } }
        Excon::Utils.request_uri(connection.data.merge(params))
      end
    end

    test('detecting default ports') do
      tests('http default port').returns true do
        datum = {
          scheme: 'http',
          port: 80
        }

        Excon::Utils.default_port?(datum)
      end

      tests('http nonstandard port').returns false do
        datum = {
          scheme: 'http',
          port: 9292
        }

        Excon::Utils.default_port?(datum)
      end

      tests('https standard port').returns true do
        datum = {
          scheme: 'https',
          port: 443
        }

        Excon::Utils.default_port?(datum)
      end

      tests('https nonstandard port').returns false do
        datum = {
          scheme: 'https',
          port: 8443
        }

        Excon::Utils.default_port?(datum)
      end

      tests('unix socket').returns false do
        datum = {
          scheme: 'unix'
        }

        Excon::Utils.default_port?(datum)
      end
    end
  end
end
