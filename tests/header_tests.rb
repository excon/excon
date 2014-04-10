Shindo.tests('Excon response header support') do
  env_init

  tests('Excon::Headers storage') do
    headers = Excon::Headers.new
    headers['Exact-Case'] = 'expected'

    tests('stores and retrieves as received').returns('expected') do
      headers['Exact-Case']
    end

    tests('enumerates keys as received').returns(['Exact-Case', 'Another-Header']) do
      headers['Another-Header'] = 'as-is'

      headers.keys
    end

    tests('supports case-insensitive access').returns('expected') do
      headers['EXACT-CASE']
    end

    tests('but still returns nil for missing keys').returns(nil) do
      headers['Missing-Header']
    end

    tests('Hash methods for reading') do
      headers['Exact-Case'] = 'expected'
      tests('#assoc').returns(['Exact-Case', 'expected']) do
        headers.assoc('exact-case')
      end
    end
  end

  with_rackup('response_header.ru') do

    tests('Response#get_header') do
      connection = nil
      response = nil

      tests('with variable header capitalization') do

        tests('response.get_header("mixedcase-header")').returns('MixedCase') do
          connection = Excon.new('http://foo.com:8080', :proxy => 'http://127.0.0.1:9292')
          response = connection.request(:method => :get, :path => '/foo')

          response.get_header("mixedcase-header")
        end

        tests('response.get_header("uppercase-header")').returns('UPPERCASE') do
          response.get_header("uppercase-header")
        end

        tests('response.get_header("lowercase-header")').returns('lowercase') do
          response.get_header("lowercase-header")
        end

      end

      tests('when provided key capitalization varies') do

        tests('response.get_header("MIXEDCASE-HEADER")').returns('MixedCase') do
          response.get_header("MIXEDCASE-HEADER")
        end

        tests('response.get_header("MiXeDcAsE-hEaDeR")').returns('MixedCase') do
          response.get_header("MiXeDcAsE-hEaDeR")
        end

      end

      tests('when header is unavailable') do

        tests('response.get_header("missing")').returns(nil) do
          response.get_header("missing")
        end

      end

    end

  end

  env_restore
end
