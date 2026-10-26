require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

task :default => :test

desc "test if bundled certs are up to date"
task :test_certs do
  # test curl bundle for end-users
  require File.join(File.dirname(__FILE__), 'lib', 'excon')
  require 'tempfile'
  local = File.read(File.join(File.dirname(__FILE__), 'data', 'cacert.pem'))
  data = Excon.get("https://curl.se/ca/cacert.pem").body
  # Not sure why, but comparing local to data directly fails.
  # Writing to a tempfile, reading, and then testing works as expected.
  tempfile = Tempfile.new('cacert.pem')
  tempfile.write(data)
  tempfile.rewind
  remote = tempfile.read
  tempfile.close
  tempfile.unlink
  if local == remote
    puts "Bundled default cert is up to date."
  else
    puts "! Bundled default cert is out of date!"
  end

  # test expiry of self-signed certs
  expiring = Dir.glob(File.join(File.dirname(__FILE__), 'tests', 'data', '*.crt')).select do |path|
    OpenSSL::X509::Certificate.new(File.read(path)).not_after < Time.now + (365 * 24 * 60 * 60)
  end
  if expiring.empty?
    puts "Test certs are not expiring within a year."
  else
    puts "! Test certs expiring within a year (run `rake update_test_certs`): #{expiring.map { |path| File.basename(path) }.join(', ')}"
  end

  exit(local == remote && expiring.empty?)
end

desc "update bundled certs"
task :update_certs => [:update_cacert, :update_test_certs]

desc "update bundled curl CA bundle"
task :update_cacert do
  # update curl bundle for end-users
  require File.join(File.dirname(__FILE__), 'lib', 'excon')
  File.open(File.join(File.dirname(__FILE__), 'data', 'cacert.pem'), 'w') do |file|
    data = Excon.get("https://curl.se/ca/cacert.pem").body
    file.write(data)
  end
end

desc "regenerate self-signed certs for tests"
task :update_test_certs do
  require 'openssl'
  dir = File.join(File.dirname(__FILE__), 'tests', 'data')

  # writes tests/data/<name>.cert.{key,crt}, self-signed unless issuer is given
  generate = lambda do |name, subject, extensions, issuer = nil|
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = OpenSSL::BN.rand(64)
    cert.subject = OpenSSL::X509::Name.parse(subject)
    cert.issuer = issuer ? issuer[:cert].subject : cert.subject
    cert.public_key = key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + (3650 * 24 * 60 * 60)

    factory = OpenSSL::X509::ExtensionFactory.new
    factory.subject_certificate = cert
    factory.issuer_certificate = issuer ? issuer[:cert] : cert
    cert.add_extension(factory.create_extension('subjectKeyIdentifier', 'hash'))
    cert.add_extension(factory.create_extension('authorityKeyIdentifier', 'keyid:always'))
    extensions.each { |extension| cert.add_extension(factory.create_extension(*extension)) }
    cert.sign(issuer ? issuer[:key] : key, OpenSSL::Digest.new('SHA256'))

    File.write(File.join(dir, "#{name}.cert.key"), key.to_pem)
    File.write(File.join(dir, "#{name}.cert.crt"), cert.to_pem)
    { key: key, cert: cert }
  end

  ca = [['basicConstraints', 'CA:TRUE', true]]
  generate.call('127.0.0.1', '/CN=127.0.0.1/O=excon', ca)
  # excon is also the root for the client chain, so the chain must be regenerated with it
  root = generate.call('excon', '/CN=excon/O=excon', ca)
  intermediate = generate.call(
    'excon_intermediate', '/O=excon/CN=excon intermediate',
    [['basicConstraints', 'CA:TRUE,pathlen:0', true], ['keyUsage', 'digitalSignature,keyCertSign,cRLSign', true]],
    root
  )
  generate.call('excon_client', '/O=excon/CN=excon client', [['basicConstraints', 'CA:FALSE']], intermediate)
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/#{name}.rb"
end

desc "check ssl settings"
task :hows_my_ssl do
  require File.join(File.dirname(__FILE__), 'lib', 'excon')
  data = Excon.get("https://www.howsmyssl.com/a/check").body
  puts data
end
