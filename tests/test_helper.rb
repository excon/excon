require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler'

Bundler.require(:default, :development)

def basic_tests(url = 'http://127.0.0.1:9292')

  connection = Excon.new(url, :ssl_verify_peer => false)

  tests('GET /content-length/100') do
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

    tests("deprecated block usage").returns(['x' * 100, 0, 100]) do
      data = []
      connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_length, total_length|
        data = [chunk, remaining_length, total_length]
      end
      data
    end

    tests("response_block usage").returns(['x' * 100, 0, 100]) do
      data = []
      response_block = lambda do |chunk, remaining_length, total_length|
        data = [chunk, remaining_length, total_length]
      end
      connection.request(:method => :get, :path => '/content-length/100', :response_block => response_block)
      data
    end

  end

  tests('POST /body-sink') do

    tests('response.body').returns("5000000") do
      response = connection.request(:method => :post, :path => '/body-sink', :headers => { 'Content-Type' => 'text/plain' }, :body => 'x' * 5_000_000)
      response.body
    end

    tests('empty body').returns('0') do
      response = connection.request(:method => :post, :path => '/body-sink', :headers => { 'Content-Type' => 'text/plain' }, :body => '')
      response.body
    end

  end

  tests('POST /echo') do

    tests('without request_block').returns('x' * 100) do
      response = connection.request(:method => :post, :path => '/echo', :body => 'x' * 100)
      response.body
    end

    tests('with request_block').returns('x' * 100) do
      data = ['x'] * 100
      request_block = lambda do
        data.shift.to_s
      end
      response = connection.request(:method => :post, :path => '/echo', :request_block => request_block)
      response.body
    end

  end

  tests('PUT /echo') do

    tests('without request_block').returns('x' * 100) do
      response = connection.request(:method => :put, :path => '/echo', :body => 'x' * 100)
      response.body
    end

    tests('request_block usage').returns('x' * 100) do
      data = ['x'] * 100
      request_block = lambda do
        data.shift.to_s
      end
      response = connection.request(:method => :put, :path => '/echo', :request_block => request_block)
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
