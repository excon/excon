Shindo.tests('Excon stubs') do
  tests("stub({:method => :get}, {:body => 'body', :status => 200})") do

    Excon.stub({:method => :get}, {:body => 'body', :status => 200})

    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:method => :get, :path => '/content-length/100')

    tests('response.body').returns('body') do
      response.body
    end

    tests('response.headers').returns({}) do
      response.headers
    end

    tests('response.status').returns(200) do
      response.status
    end

  end
end
