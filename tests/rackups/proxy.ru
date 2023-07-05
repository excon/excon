require 'sinatra'

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('*') do
    headers(
      "Sent-Request-Uri" => request.env['REQUEST_URI'].to_s,
      "Sent-Host" => request.env['HTTP_HOST'].to_s,
      "Sent-Proxy-Connection" => request.env['HTTP_PROXY_CONNECTION'].to_s
    )
    'proxied content'
  end
end

run App
