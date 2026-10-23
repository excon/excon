app = lambda do |env|
  if %w[GET HEAD].include?(env['REQUEST_METHOD']) && env['PATH_INFO'] =~ %r{\A/id/([^/]+)/wait/([^/]+)\z}
    id = Regexp.last_match(1)
    wait = Regexp.last_match(2)
    sleep(wait.to_i)
    [200, { 'content-type' => 'text/plain' }, [id]]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
