Shindo.tests('Excon redirector support') do
  env_init

  tests("request(:method => :get, :path => '/old').body").returns('new') do
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

    Excon.get(
      'http://127.0.0.1:9292',
      :path         => '/old',
      :middlewares  => Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower],
      :mock         => true
    ).body
  end

  env_restore
end

Shindo.tests('Excon redirect support for relative Location headers') do
  env_init

  tests("request(:method => :get, :path => '/old').body").returns('new') do
    Excon.stub(
      { :path => '/old' },
      {
        :headers  => { 'Location' => '/new' },
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

    Excon.get(
      'http://127.0.0.1:9292',
      :path         => '/old',
      :middlewares  => Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower],
      :mock         => true
    ).body
  end

  env_restore
end
