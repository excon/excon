require 'openssl'
require 'sinatra'
require 'webrick'
require 'webrick/https'

class App < Sinatra::Base
  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end
end

Rack::Handler::WEBrick.run(App, {
  :Port             => 9443,
  :SSLCertName      => [["CN", WEBrick::Utils::getservername]],
  :SSLEnable        => true,
  :SSLVerifyClient  => OpenSSL::SSL::VERIFY_NONE
})
