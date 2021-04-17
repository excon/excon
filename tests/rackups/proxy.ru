require 'sinatra'
require File.join(File.dirname(__FILE__), 'webrick_patch')

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  # a bit of a hack to handle the proxy CONNECT request since 
  # Sinatra doesn't support it by default
  configure do
    class << Sinatra::Base
      def connect(path, opts={}, &block)
        route 'CONNECT', path, opts, &block
      end
    end
    Sinatra::Delegator.delegate :options
  end

  connect('*') do
    headers(
      "Sent-Request-Uri" => request.env['REQUEST_URI'].to_s,
      "Sent-Host" => request.env['HTTP_HOST'].to_s,
      "Sent-Proxy-Connection" => request.env['HTTP_PROXY_CONNECTION'].to_s,
      "X-Proxy-Id" => request.env['X_PROXY_ID'].to_s
    )

    halt 200, 'proxy connect successful'
  end

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
