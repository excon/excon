TEST_SUITE_DEFAULTS = {
  :connect_timeout  => 5,
  :read_timeout     => 5,
  :write_timeout    => 5
}

require 'bundler/setup'
require 'excon'
require 'delorean'
require 'open4'
require 'webrick'

require './spec/helpers/warning_helpers.rb'

Excon.set_raise_on_warnings!(true)

def basic_tests(url = 'http://127.0.0.1:9292', options = {})
  ([true, false] * 2).combination(2).to_a.uniq.each do |nonblock, persistent|
    connection = nil
    test do
      options = options.merge({:ssl_verify_peer => false, :nonblock => nonblock, :persistent => persistent })
      connection = Excon.new(url, options)
      true
    end

    tests("nonblock => #{nonblock}, persistent => #{persistent}") do

      tests('method and path defaults') do
        tests('request().body').returns('GET /') do
          response = connection.request(:path => '/')
          response.body
        end

        tests("request(:headers => {'host' => '127.0.0.1'})").returns('GET /') do
          response = connection.request(:headers => {'host' => '127.0.0.1'})
          response.body
        end

        tests('request(:method => :get).body').returns('GET /') do
          response = connection.request(:method => :get)
          response.body
        end

        tests("request(:path => '/').body").returns('GET /') do
          response = connection.request(:path => '/')
          response.body
        end

        tests("request(:method => :get, :path => '/').body").returns('GET /') do
          response = connection.request(:method => :get, :path => '/')
          response.body
        end
      end

      tests('GET /content-length/100') do
        response = nil

        tests('response.status').returns(200) do
          response = connection.request(:method => :get, :path => '/content-length/100')

          response.status
        end

        tests('response[:status]').returns(200) do
          response[:status]
        end

        tests("response.headers['Content-Length']").returns('100') do
          response.headers['Content-Length']
        end

        tests("response.headers['Content-Type']").returns('text/html;charset=utf-8') do
          response.headers['Content-Type']
        end

        test("Time.parse(response.headers['Date']).is_a?(Time)") do
          pending if connection.data[:scheme] == Excon::UNIX
          Time.parse(response.headers['Date']).is_a?(Time)
        end

        test("!!(response.headers['Server'] =~ /^WEBrick/)") do
          pending if connection.data[:scheme] == Excon::UNIX
          !!(response.headers['Server'] =~ /^WEBrick/)
        end

        tests("response.headers['Custom']").returns("Foo: bar") do
          response.headers['Custom']
        end

        tests("response.remote_ip").returns("127.0.0.1") do
          pending if connection.data[:scheme] == Excon::UNIX
          response.remote_ip
        end

        tests("response.body").returns('x' * 100) do
          response.body
        end

        tests("deprecated block usage").returns(['x' * 100, 0, 100]) do
          data = []
          silence_warnings do
            connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_length, total_length|
              data = [chunk, remaining_length, total_length]
            end
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
        tests('with file').returns('x' * 100 + "\n") do
          file_path = File.join(File.dirname(__FILE__), "data", "xs")
          response = connection.request(:method => :post, :path => '/echo', :headers => { 'Content-Type' => 'text/plain' }, :body => File.open(file_path))
          response.body
        end

        tests('without request_block').returns('x' * 100) do
          response = connection.request(:method => :post, :path => '/echo', :headers => { 'Content-Type' => 'text/plain' }, :body => 'x' * 100)
          response.body
        end

        tests('with request_block').returns('x' * 100) do
          data = Array.new(100, 'x')
          request_block = lambda do
            data.shift.to_s
          end
          response = connection.request(:method => :post, :path => '/echo', :headers => { 'Content-Type' => 'text/plain' }, :request_block => request_block)
          response.body
        end

        tests('with multi-byte strings') do
          body = "\xC3\xBC" * 100
          headers = { 'Custom' => body.dup }
          body.force_encoding('BINARY')
          headers['Custom'].force_encoding('UTF-8')
          headers['Content-Type'] = 'text/plain'

          returns(body, 'properly concatenates request+headers and body') do
            response = connection.request(:method => :post, :path => '/echo', :headers => headers, :body => body)
            response.body
          end
        end
      end

      tests('PUT /echo') do

        tests('with file').returns('x' * 100 + "\n") do
          file_path = File.join(File.dirname(__FILE__), "data", "xs")
          response = connection.request(:method => :put, :path => '/echo', :body => File.open(file_path))
          response.body
        end

        tests('without request_block').returns('x' * 100) do
          response = connection.request(:method => :put, :path => '/echo', :body => 'x' * 100)
          response.body
        end

        tests('request_block usage').returns('x' * 100) do
          data = Array.new(100, 'x')
          request_block = lambda do
            data.shift.to_s
          end
          response = connection.request(:method => :put, :path => '/echo', :request_block => request_block)
          response.body
        end

        tests('with multi-byte strings') do
          body = "\xC3\xBC" * 100
          headers = { 'Custom' => body.dup }
          body.force_encoding('BINARY')
          headers['Custom'].force_encoding('UTF-8')

          returns(body, 'properly concatenates request+headers and body') do
            response = connection.request(:method => :put, :path => '/echo', :headers => headers, :body => body)
            response.body
          end
        end

      end

      tests('should succeed with tcp_nodelay').returns(200) do
        options = options.merge(:ssl_verify_peer => false, :nonblock => nonblock, :tcp_nodelay => true)
        connection = Excon.new(url, options)
        response = connection.request(:method => :get, :path => '/content-length/100')
        response.status
      end

    end
  end
end


# expected values: the response, in pieces, and a timeout after each piece
STREAMING_PIECES = %w{Hello streamy world}
STREAMING_TIMEOUT = 0.1

def streaming_tests(protocol)
  conn = nil
  test do
    conn = Excon.new("#{protocol}://127.0.0.1:9292/", :ssl_verify_peer => false)
    true
  end

  # expect the full response as a string
  # and expect it to take a (timeout * pieces) seconds
  tests('simple blocking request on streaming endpoint').returns([STREAMING_PIECES.join(''),'response time ok']) do
    start = Time.now
    ret = conn.request(:method => :get, :path => '/streamed/simple').body

    if Time.now - start <= STREAMING_TIMEOUT*3
      [ret, 'streaming response came too quickly']
    else
      [ret, 'response time ok']
    end
  end

  # expect the full response as a string and expect it to
  # take a (timeout * pieces) seconds (with fixed Content-Length header)
  tests('simple blocking request on streaming endpoint with fixed length').returns([STREAMING_PIECES.join(''),'response time ok']) do
    start = Time.now
    ret = conn.request(:method => :get, :path => '/streamed/fixed_length').body

    if Time.now - start <= STREAMING_TIMEOUT*3
      [ret, 'streaming response came too quickly']
    else
      [ret, 'response time ok']
    end
  end

  # expect each response piece to arrive to the body right away
  # and wait for timeout until next one arrives
  def timed_streaming_test(conn, path, timeout)
    ret = []
    timing = 'response times ok'
    start = Time.now
    conn.request(:method => :get, :path => path, :response_block => lambda do |c,r,t|
      # add the response
      ret.push(c)
      # check if the timing is ok
      # each response arrives after timeout and before timeout + 1
      cur_time = Time.now - start
      if cur_time < ret.length * timeout or cur_time > (ret.length+1) * timeout
        timing = 'response time not ok!'
      end
    end)
    # validate the final timing
    if Time.now - start <= timeout*3
      timing = 'final timing was not ok!'
    end
    [ret, timing]
  end

  tests('simple request with response_block on streaming endpoint').returns([STREAMING_PIECES,'response times ok']) do
    timed_streaming_test(conn, '/streamed/simple', STREAMING_TIMEOUT)
  end

  tests('simple request with response_block on streaming endpoint with fixed length').returns([STREAMING_PIECES,'response times ok']) do
    timed_streaming_test(conn, '/streamed/fixed_length', STREAMING_TIMEOUT)
  end
end


PROXY_ENV_VARIABLES = %w{http_proxy https_proxy no_proxy} # All lower-case

def env_init(env={})
  current = {}
  PROXY_ENV_VARIABLES.each do |key|
    current[key] = ENV.delete(key)
    current[key.upcase] = ENV.delete(key.upcase)
  end
  env_stack << current

  env.each do |key, value|
    ENV[key] = value
  end
end

def env_restore
  ENV.update(env_stack.pop)
end

def env_stack
  @env_stack ||= []
end

def capture_response_block
  captures = []
  yield lambda {|chunk, remaining_bytes, total_bytes|
    captures << [chunk, remaining_bytes, total_bytes]
  }
  captures
end

def launch_process(*args)
  if RUBY_PLATFORM == 'java'
    IO.popen4(*args)
  else
    Open4.popen4(*args)
  end
end

def cleanup_process(pid)
  Process.kill('KILL', pid)
  Process.wait(pid) unless RUBY_PLATFORM == 'java'
end

def rackup_path(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), 'rackups', *parts))
end

def wait_for_message(io, msg)
  process_stderr = +''
  until (line = io.gets)&.include?(msg)
    # nil means we have reached the end of stream
    raise process_stderr if line.nil?

    process_stderr << line
  end
end

def with_rackup(name, host="127.0.0.1")
  pid, w, r, e = launch_process(RbConfig.ruby, "-S", "rackup", "-s", "webrick", "--host", host, rackup_path(name))
  wait_for_message(e, 'Rackup::Handler::WEBrick::Server#start')
  yield
ensure
  cleanup_process(pid)

  # dump server errors
  lines = e.read.split($/)
  while line = lines.shift
    case line
    when /(ERROR|Error)/
      unless line.match?(/(null cert chain|did not return a certificate|SSL_read:: internal error)/)
        in_err = true
        puts
      end
    when /^(127|localhost)/
      in_err = false
    end
    puts line if in_err
  end
end

def with_unicorn(name, listen='127.0.0.1:9292')
  unless RUBY_PLATFORM == 'java'
    unix_socket = listen.sub('unix://', '') if listen.start_with? 'unix://'
    pid, w, r, e = launch_process(RbConfig.ruby, "-S", "unicorn", "--no-default-middleware","-l", listen, rackup_path(name))
    wait_for_message(e, 'worker=0 ready')
  else
    # need to find suitable server for jruby
  end
  yield
ensure
  cleanup_process(pid)

  if not unix_socket.nil? and File.exist?(unix_socket)
    File.delete(unix_socket)
  end
end

def server_path(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), 'servers', *parts))
end

def with_server(name)
  pid, w, r, e = launch_process(RbConfig.ruby, server_path("#{name}.rb"))
  wait_for_message(e, 'ready')
  yield
ensure
  cleanup_process(pid)
end

# A tiny fake SSL streaming server
def with_ssl_streaming(port, pieces, delay)
  key_file = File.join(File.dirname(__FILE__), 'data', '127.0.0.1.cert.key')
  cert_file = File.join(File.dirname(__FILE__), 'data', '127.0.0.1.cert.crt')

  ctx = OpenSSL::SSL::SSLContext.new
  ctx.key = OpenSSL::PKey::RSA.new(File.read(key_file))
  ctx.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))

  tcp = TCPServer.new(port)
  ssl = OpenSSL::SSL::SSLServer.new(tcp, ctx)

  Thread.new do
    loop do
      begin
        conn = ssl.accept
      rescue IOError => e
        # we're closing the socket from another thread, which makes `accept` complain
        break if e.to_s.include?('stream closed')
        raise
      end

      Thread.new do
        begin
          req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
          req.parse(conn)

          conn << "HTTP/1.1 200 OK\r\n\r\n"
          if req.path == "streamed/fixed_length"
            conn << "Content-Length: #{pieces.join.length}\r\n"
          end
          conn.flush

          pieces.each do |piece|
            sleep(delay)
            conn.write(piece)
            conn.flush
          end
        ensure
          conn.close
        end
      end
    end
  end
  yield
  ssl.close
end
