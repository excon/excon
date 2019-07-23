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
  end
end
