require 'sinatra'

class App < Sinatra::Base
  get('/bar') do
    headers(
      "Sent-Request-Uri" => request.env['REQUEST_URI'].to_s,
      "Sent-Host" => request.env['HTTP_HOST'] || [request.env['SERVER_NAME'].to_s, request.env['SERVER_PORT']].join(':'),
      "Sent-Proxy-Connection" => request.env['HTTP_PROXY_CONNECTION'].to_s,
      "Env" => request.env.inspect
    )
    'proxied content'
  end
end

run App
