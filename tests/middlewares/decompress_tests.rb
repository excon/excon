Shindo.tests('Excon decompression support') do
  env_init

  with_rackup('deflater.ru') do
    connection = Excon.new(
      'http://127.0.0.1:9292/echo',
      :body         => 'x' * 100,
      :method       => :post,
      :middlewares  => Excon.defaults[:middlewares] + [Excon::Middleware::Decompress]
    )

    tests('deflate').returns('x' * 100) do
      response = connection.request(:headers => { 'Accept-Encoding' => 'deflate' })
      response.body
    end

    tests('gzip').returns('x' * 100) do
      response = connection.request(:headers => { 'Accept-Encoding' => 'gzip' })
      response.body
    end
  end

  env_restore
end
