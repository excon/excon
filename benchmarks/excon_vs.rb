require File.join(File.dirname(__FILE__), '..', 'lib/excon')

require 'benchmark'
require 'open-uri'

COUNT = 10
data = "Content-Length: 100"
Benchmark.bmbm(25) do |bench|
  bench.report('excon') do
    COUNT.times do
      Excon.new('http://www.google.com').request(:method => 'GET', :path => '/')
    end
  end
  bench.report('excon (persistent)') do
    excon = Excon.new('http://www.google.com')
    COUNT.times do
      excon.request(:method => 'GET', :path => '/')
    end
  end
  bench.report('open-uri') do
    COUNT.times do
      open('http://www.google.com/').read
    end
  end
end
