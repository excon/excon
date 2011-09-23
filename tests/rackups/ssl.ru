require 'openssl'
require 'sinatra'
require 'webrick'
require 'webrick/https'

class App < Sinatra::Base
  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end

  post('/body-sink') do
    request.body.read.size.to_s
  end
end

Rack::Handler::WEBrick.run(App, {
  :Port             => 9443,
  :SSLCertName      => [["CN", WEBrick::Utils::getservername]],
  :SSLEnable        => true,
  :SSLVerifyClient  => OpenSSL::SSL::VERIFY_NONE
})
