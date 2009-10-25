require File.join(File.dirname(__FILE__), '..', 'lib/excon')

x = Excon.new('http://www.google.com')

10.times do
p x.request(
  :method => 'GET',
  :path => '/'
)
end

# require 'open-uri'
# 10.times do
#   p open('http://www.google.com').read
# end