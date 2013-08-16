Shindo.tests('Excon redirector support') do
  env_init

  connection = Excon.new(
    'http://127.0.0.1:9292',
    :middlewares  => Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower],
    :mock         => true
  )

  Excon.stub(
    { :path => '/old' },
    {
      :headers  => { 'Location' => 'http://127.0.0.1:9292/new' },
      :body     => 'old',
      :status   => 301
    }
  )

  Excon.stub(
    { :path => '/new' },
    {
      :body     => 'new',
      :status   => 200
    }
  )

  tests("request(:method => :get, :path => '/old').body").returns('new') do
    connection.request(:method => :get, :path => '/old').body
  end

  env_restore
end
