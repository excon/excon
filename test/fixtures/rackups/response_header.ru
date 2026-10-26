app = lambda do |env|
  if %w[GET HEAD].include?(env['REQUEST_METHOD']) && env['PATH_INFO'] == '/foo'
    headers = {
      'content-type' => 'text/plain',
      'MixedCase-Header' => 'MixedCase',
      'UPPERCASE-HEADER' => 'UPPERCASE',
      'lowercase-header' => 'lowercase'
    }
    [200, headers, ['primary content']]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
