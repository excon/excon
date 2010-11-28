require 'rubygems' if RUBY_VERSION < '1.9'

require 'benchmark'

num1 = "num1"
num2 = "num2"

iters = 100000

Benchmark.bmbm do |x|
  x.report('symbol') do
    iters.times.each do
      :"A#{num1}:C#{num2}"
    end
  end

  x.report('string') do
    iters.times.each do
      "A#{num1}:C#{num2}"
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
