app = lambda do |env|
  method = env['REQUEST_METHOD'] == 'HEAD' ? 'GET' : env['REQUEST_METHOD']
  if env['PATH_INFO'] == '/' && %w[GET POST DELETE].include?(method)
    [200, { 'content-type' => 'text/plain' }, [method]]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
