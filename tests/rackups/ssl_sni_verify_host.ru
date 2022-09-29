require 'openssl'
require 'webrick'
require 'webrick/https'

require File.join(File.dirname(__FILE__), 'basic')
key_file = File.join(File.dirname(__FILE__), '..', 'data', 'excon.cert.key')
cert_file = File.join(File.dirname(__FILE__), '..', 'data', 'excon.cert.crt')

# Responds with generated certificate by default
# Responds with `excon.cert` for when SNI is `excon`
Rack::Handler::WEBrick.run(Basic,
  :Port             => 9443,
  :SSLEnable        => true,
  :SSLCertName => [%w{CN example.com}],
) do |server|
  excon_vhost = ::WEBrick::HTTPServer.new(
    :SSLEnable        => true,
    :Port             => 9443,
    :ServerName       => "excon",
    :SSLPrivateKey    => OpenSSL::PKey::RSA.new(File.open(key_file).read),
    :SSLCertificate   => OpenSSL::X509::Certificate.new(File.open(cert_file).read),
    :SSLCACertificateFile => cert_file,
    :SSLVerifyClient  => OpenSSL::SSL::VERIFY_NONE,
    :DoNotListen         => true
  )
  server.virtual_host excon_vhost
end
