require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

Excon.mock!

request = {
  :host   => 'www.google.com',
  :method => 'GET',
  :path   => '/'
}
response = Excon::Response.new({
  :status   => 200,
  :headers  => { 'Content-Length' => '11' },
  :body     => 'Hello World'
})
Excon.mocks[request] = response

Shindo.tests do

  before do
    @connection = Excon.new('http://www.google.com')
    @response = @connection.request({
      :host   => 'www.google.com',
      :method => 'GET',
      :path   => '/'
    })
  end

  test("status => 200") do
    @response.status == 200
  end

  test("headers => { 'Content-Length' => '11' }") do
    @response.headers == { 'Content-Length' => '11' }
  end

  test("body => 'Hello World") do
    @response.body == 'Hello World'
  end

end
