app = lambda do |env|
  if env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == '/'
    body = env.filter_map { |k, v| "#{Regexp.last_match(1).downcase}: #{v}\n" if k =~ /http_(.*)/i }.join
    [200, { 'content-type' => 'text/plain' }, [body]]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
