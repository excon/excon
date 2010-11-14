require 'rubygems'
require 'sinatra/base'

require File.join(File.dirname(__FILE__), '..', 'lib', 'excon')

module Excon
  class Server < Sinatra::Base

    def self.run
      Rack::Handler::WEBrick.run(
        Excon::Server.new,
        :Port => 9292,
        :AccessLog => [],
        :Logger => WEBrick::Log.new(nil, WEBrick::Log::ERROR)
      )
    end

    get '/data/:amount' do |amount|
      'x' * amount.to_i
    end

  end
end

def with_server(&block)
  pid = Process.fork do
    Excon::Server.run
  end
  loop do
    sleep(1)
    begin
      Excon.get('http://localhost:9292/api/foo')
      break
    rescue
    end
  end
  yield
ensure
  Process.kill(9, pid)
end

require 'em-http-request'
require 'httparty'
require 'net/http'
require 'open-uri'
require 'rest_client'
require 'tach'
require 'typhoeus'

url = 'http://localhost:9292/data/1000'

# with_server do
#   EventMachine.run {
#     http = EventMachine::HttpRequest.new(url).get
#
#     http.callback {
#       p http.response
#       EventMachine.stop
#     }
#   }
# end

with_server do

  Tach.meter(1000) do

    tach('em-http-request') do
      EventMachine.run {
        http = EventMachine::HttpRequest.new(url).get

        http.callback {
          http.response
          EventMachine.stop
        }
      }
    end

    tach('Excon') do
      Excon.get(url).body
    end

    excon = Excon.new(url)
    tach('Excon (persistent)') do
      excon.request(:method => 'get').body
    end

    tach('HTTParty') do
      HTTParty.get(url).body
    end

    tach('Net::HTTP') do
      # Net::HTTP.get('localhost', '/data/1000', 9292)
      Net::HTTP.start('localhost', 9292) {|http| http.get('/data/1000').body }
    end

    Net::HTTP.start('localhost', 9292) do |http|
      tach('Net::HTTP (persistent)') do
        http.get('/data/1000').body
      end
    end

    tach('open-uri') do
      open(url).read
    end

    tach('RestClient') do
      RestClient.get(url)
    end

    tach('Typhoeus') do
      Typhoeus::Request.get(url).body
    end

  end
end

# +------------------------+----------+
# | tach                   | total    |
# +------------------------+----------+
# | em-http-request        | 3.828347 |
# +------------------------+----------+
# | Excon                  | 1.541997 |
# +------------------------+----------+
# | Excon (persistent)     | 1.454728 |
# +------------------------+----------+
# | HTTParty               | 2.551734 |
# +------------------------+----------+
# | Net::HTTP              | 2.342450 |
# +------------------------+----------+
# | Net::HTTP (persistent) | 2.434209 |
# +------------------------+----------+
# | open-uri               | 2.898245 |
# +------------------------+----------+
# | RestClient             | 2.834506 |
# +------------------------+----------+
# | Typhoeus               | 1.828265 |
# +------------------------+----------+
