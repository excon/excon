require 'openssl'
require 'webrick'
require 'webrick/https'

require File.join(File.dirname(__FILE__), 'basic')

Rack::Handler::WEBrick.run(Basic, {
  :Port             => 9443,
  :SSLCertName      => [["CN", WEBrick::Utils::getservername]],
  :SSLEnable        => true,
  :SSLVerifyClient  => OpenSSL::SSL::VERIFY_NONE
})
