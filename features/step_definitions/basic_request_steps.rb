require 'time'

# Executed after each scenario taggeed with @requests, expects @server to be
# defined
After('@requests') do
  @server.stop
end

Given('a basic web server') do
  abs_file = webrick_path('basic.ru')
  @server = Excon::Test::Server.new(webrick: abs_file, before: :start, after: :stop)
  @server.start
end

Given('a basic excon client') do
  @conn = Excon::Connection.new(host: '127.0.0.1',
                                hostname: '127.0.0.1',
                                nonblock: false,
                                port: 9292,
                                scheme: 'http',
                                ssl_verify_peer: false)
  expect(@conn).to be_an_instance_of Excon::Connection
end

When("a user gets {string}") do |string|
  @response = @conn.request(method: :get, path: string)
end

Then('the user should receive a response') do
  expect(@response).to be_an_instance_of Excon::Response
end

Then("the status is {string}") do |string|
  expect(@response.status).to eq string.to_i
  expect(@response[:status]).to eq string.to_i
end

Then('the Date header field is a valid date') do
  if RUBY_PLATFORM == 'java' && @conn.data[:scheme] == Excon::UNIX
    pending('until puma responds with a date header')
  else
    time = Time.parse(@response.headers['Date'])
    expect(time.is_a?(Time)).to be true
  end
end

Then(/the (\S+) header field (matches|is) \"(\S+)\"/) do |field, op, val|
  is_unix_socket = @conn.data[:scheme] == Excon::UNIX
  pending('until unix_socket response has server header') if is_unix_socket
  case op
  when 'matches'
    expect(!!(@response.headers[field] =~ /^#{val}/)).to be true
  when 'is'
    expect(@response.headers[field]).to eq val
  else
    raise "I don't know about #{op}, help me out?"
  end
end

Then("the remote ip is {string}") do |string|
  pending('until pigs can fly') if @conn.data[:scheme] == Excon::UNIX
  expect(@response.remote_ip).to eq string
end
