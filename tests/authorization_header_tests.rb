with_rackup('basic_auth.ru') do
  Shindo.tests('Excon basics (Authorization data redacted)') do
    cases = [
             ['user & pass', 'http://user1:pass1@foo.com/', 'Basic dXNlcjE6cGFzczE='],
             ['user no pass', 'http://three_user@foo.com/', 'Basic dGhyZWVfdXNlcjo='],
             ['pass no user', 'http://:derppass@foo.com/', 'Basic OmRlcnBwYXNz']
            ]
    cases.each do |desc,url,auth_header|
      conn = Excon.new(url)
      test("authorization header concealed for #{desc}") do
        !conn.inspect.include?(auth_header)
      end

      test("authorization header remains correct for #{desc}") do
        conn.connection[:headers]['Authorization'] == auth_header
      end

    end
  end
end
