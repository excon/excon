Shindo.tests('Excon::Utils') do

  tests('#connection_uri') do

    expected_uri = 'unix:///tmp/some.sock'
    tests('using UNIX scheme').returns(expected_uri) do
      connection = Excon.new('unix:///some/path', :socket => '/tmp/some.sock')
      Excon::Utils.connection_uri(connection.data)
    end

    tests('using HTTP scheme') do

      expected_uri = 'http://foo.com:80'
      tests('with default port').returns(expected_uri) do
        connection = Excon.new('http://foo.com/some/path')
        Excon::Utils.connection_uri(connection.data)
      end

      expected_uri = 'http://foo.com'
      tests('without default port').returns(expected_uri) do
        connection = Excon.new('http://foo.com/some/path', :omit_default_port => true)
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

      expected_uri = 'http://foo.com:80/some/path'
      tests('without query').returns(expected_uri) do
        connection = Excon.new('http://foo.com')
        params = { :path => '/some/path' }
        Excon::Utils.request_uri(connection.data.merge(params))
      end

      expected_uri = 'http://foo.com:80/some/path?bar=that&foo=this'
      tests('with query').returns(expected_uri) do
        connection = Excon.new('http://foo.com')
        params = { :path => '/some/path', :query => { :foo => 'this', :bar => 'that' } }
        Excon::Utils.request_uri(connection.data.merge(params))
      end

    end

  end

  tests('#escape_uri').returns('/hello%20excon') do
    Excon::Utils.escape_uri('/hello excon')
  end

  tests('#unescape_uri').returns('/hello excon') do
    Excon::Utils.unescape_uri('/hello%20excon')
  end

  tests('#unescape_form').returns('message=We love excon!') do
    Excon::Utils.unescape_form('message=We+love+excon!')
  end

  tests('#split_header_value').returns(["value"]) do
    Excon::Utils.split_header_value("value")
  end

  tests('#split_header_value').returns(["value1", "value2"]) do
    Excon::Utils.split_header_value("value1, value2")
  end

  tests('#split_header_value').returns(["text/html;q=0.5", "application/json; version=1"]) do
    Excon::Utils.split_header_value("text/html;q=0.5, application/json; version=1")
  end

  tests('#split_header_value').returns(["foo/bar;key=\"A,B,C\""]) do
    Excon::Utils.split_header_value("foo/bar;key=\"A,B,C\"")
  end

  tests('#split_header_value').returns([]) do
    # previous implementation would hang on this, so test is here to prevent regression
    Timeout.timeout(0.1) do
      Excon::Utils.split_header_value("uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu\",")
    end
  end

end
