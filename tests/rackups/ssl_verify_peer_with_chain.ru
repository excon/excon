require 'openssl'
require 'rackup/handler/webrick'
require 'webrick'
require 'webrick/https'

require File.join(File.dirname(__FILE__), 'basic')
key_file = File.join(File.dirname(__FILE__), '..', 'data', 'excon_client.cert.key')
cert_file = File.join(File.dirname(__FILE__), '..', 'data', 'excon_client.cert.crt')
cacert_file = File.join(File.dirname(__FILE__), '..', 'data', 'excon.cert.crt')
Rackup::Handler::WEBrick.run(Basic,
  :Port             => 8443,
  :SSLCertName      => [["CN", WEBrick::Utils::getservername]],
  :SSLEnable        => true,
  :SSLPrivateKey => OpenSSL::PKey::RSA.new(File.open(key_file).read),
  :SSLCertificate => OpenSSL::X509::Certificate.new(File.open(cert_file).read),
  :SSLCACertificateFile => cacert_file,
  :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
)
