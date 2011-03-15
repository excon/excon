require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    tests('GET /content-length/100') do

      connection = Excon.new('http://127.0.0.1:9292')
      response = connection.request(:method => :get, :path => '/content-length/100')

      tests('response.status').returns(200) do
        response.status
      end

      tests("response.headers['Connection']").returns('Keep-Alive') do
        response.headers['Connection']
      end

      tests("response.headers['Content-Length']").returns('100') do
        response.headers['Content-Length']
      end

      tests("response.headers['Content-Type']").returns('text/html;charset=utf-8') do
        response.headers['Content-Type']
      end

      tests("Time.parse(response.headers['Date']).is_a?(Time)") do
        Time.parse(response.headers['Date']).is_a?(Time)
      end

      tests("!!(response.headers['Server'] =~ /^WEBrick/)") do
        !!(response.headers['Server'] =~ /^WEBrick/)
      end

      tests("response.headers['Custom']").returns("Foo: bar") do
        response.headers['Custom']
      end

      tests("response.body").returns('x' * 100) do
        response.body
      end
    end
  end
end
