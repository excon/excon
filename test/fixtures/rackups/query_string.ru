app = lambda do |env|
  if %w[GET HEAD].include?(env['REQUEST_METHOD']) && env['PATH_INFO'] == '/query'
    [200, { 'content-type' => 'text/plain' }, ["query: #{env['QUERY_STRING']}"]]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
