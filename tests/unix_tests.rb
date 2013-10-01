file_name = '/tmp/unicorn.sock'
with_unicorn('basic.ru', file_name) do
  Shindo.tests('Excon basics (Unix socket)') do
    pending if RUBY_PLATFORM == 'java' # need to find suitable server for jruby
    basic_tests("unix://#{file_name}")
  end

  Shindo.tests('explicit uri passed to connection') do
    connection = Excon::Connection.new({
      :path             => file_name,
      :nonblock         => false,
      :scheme           => 'unix',
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


