require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler'

Bundler.require(:default)
Bundler.require(:benchmark)

require 'benchmark'
require 'net/http'
require 'open-uri'
require 'uri'

url   = ARGV[0] || "http://localhost:8080/" # nginx default
uri   = URI.parse(url)
iters = (ARGV[1] || 1000).to_i

Benchmark.bmbm do |x|
  x.report('em-http-request') do
    iters.times do
      EventMachine.run {
        http = EventMachine::HttpRequest.new(url).get

        http.callback {
          http.response
          EventMachine.stop
        }
      }
    end
  end

  x.report('Excon') do
    iters.times do
      Excon.get(url).body
    end
  end

  excon = Excon.new(url)
  x.report('Excon (persistent)') do
    iters.times do
      excon.request(:method => 'get').body
    end
  end

  x.report('HTTParty') do
    iters.times do
      HTTParty.get(url).body
    end
  end

  x.report('Net::HTTP') do
    # Net::HTTP.get('localhost', '/data/1000', 9292)
    iters.times do
      Net::HTTP.start(uri.host, uri.port) {|http| http.get('/data/1000').body }
    end
  end

  Net::HTTP.start(uri.host, uri.port) do |http|
    x.report('Net::HTTP (persistent)') do
      iters.times do
        http.get('/data/1000').body
      end
    end
  end

  x.report('open-uri') do
    iters.times do
      open(url).read
    end
  end

  x.report('RestClient') do
    iters.times do
      RestClient.get(url)
    end
  end

  x.report('Typhoeus') do
    iters.times do
      Typhoeus::Request.get(url).body
    end
  end

  x.report('StreamlyFFI (Persistent)') do
    conn = StreamlyFFI::Connection.new
    iters.times do
      conn.get(url)
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
