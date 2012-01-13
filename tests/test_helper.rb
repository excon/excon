require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler'

Bundler.require(:default, :development)

def basic_tests(url = 'http://127.0.0.1:9292')
  tests('GET /content-length/100') do

    connection = Excon.new(url)
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

    test("Time.parse(response.headers['Date']).is_a?(Time)") do
      Time.parse(response.headers['Date']).is_a?(Time)
    end

    test("!!(response.headers['Server'] =~ /^WEBrick/)") do
      !!(response.headers['Server'] =~ /^WEBrick/)
    end

    tests("response.headers['Custom']").returns("Foo: bar") do
      response.headers['Custom']
    end

    tests("response.body").returns('x' * 100) do
      response.body
    end

    tests("block usage").returns(['x' * 100, 0, 100]) do
      data = []
      connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_length, total_length|
        data = [chunk, remaining_length, total_length]
      end
      data
    end

  end

  tests('POST /body-sink') do

    connection = Excon.new(url)
    response = connection.request(:method => :post, :path => '/body-sink', :headers => { 'Content-Type' => 'text/plain' }, :body => 'x' * 5_000_000)

    tests('response.body').returns("5000000") do
      response.body
    end
  end
end

def rackup_path(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), 'rackups', *parts))
end

def with_rackup(name)
  unless RUBY_PLATFORM == 'java'
    GC.disable
    pid, w, r, e = Open4.popen4("rackup", rackup_path(name))
  else
    pid, w, r, e = IO.popen4("rackup", rackup_path(name))
  end
  until e.gets =~ /HTTPServer#start:/; end
  yield
ensure
  Process.kill(9, pid)
  unless RUBY_PLATFORM == 'java'
    GC.enable
    Process.wait(pid)
  end
end

def server_path(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), 'servers', *parts))
end

def with_server(name)
  unless RUBY_PLATFORM == 'java'
    GC.disable
    pid, w, r, e = Open4.popen4(server_path("#{name}.rb"))
  else
    pid, w, r, e = IO.popen4(server_path("#{name}.rb"))
  end
  until e.gets =~ /ready/; end
  yield
ensure
  Process.kill(9, pid)
  unless RUBY_PLATFORM == 'java'
    GC.enable
    Process.wait(pid)
  end
end
