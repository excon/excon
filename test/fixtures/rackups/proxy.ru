app = lambda do |env|
  if %w[GET HEAD].include?(env['REQUEST_METHOD'])
    headers = {
      'content-type' => 'text/plain',
      'sent-request-uri' => env['REQUEST_URI'].to_s,
      'sent-host' => env['HTTP_HOST'].to_s,
      'sent-proxy-connection' => env['HTTP_PROXY_CONNECTION'].to_s
    }
    [200, headers, ['proxied content']]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
