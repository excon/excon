require 'sinatra'

class App < Sinatra::Base
  get '/bar' do
    headers "Sent-Proxy-Connection" => request.env['HTTP_PROXY_CONNECTION']
    'proxied content'
  end
end

run App
