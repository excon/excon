require File.join(File.dirname(__FILE__), '..', 'lib/excon')

Excon.mock!

request = {
  :host   => 'www.google.com',
  :method => 'GET',
  :path   => '/'
}
response = {
  :status   => 200,
  :headers  => { 'Content-Length' => '11' },
  :body     => 'Hello World'
}
Excon.mocks[request] = response

x = Excon.new('http://www.google.com')

10.times do
p x.request(
  :host   => 'www.google.com',
  :method => 'GET',
  :path   => '/'
)
end

# require 'open-uri'
# 10.times do
#   p open('http://www.google.com').read
# end