Shindo.tests('Excon stubs') do
  Excon.mock = true

  tests("missing stub").raises(Excon::Errors::StubNotFound) do
    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:method => :get, :path => '/content-length/100')
  end

  tests("stub({})").raises(ArgumentError) do
    Excon.stub({})
  end

  tests("stub({}, {}) {}").raises(ArgumentError) do
    Excon.stub({}, {}) {}
  end

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

    Excon.stubs.pop

  end

  tests("stub({:body => 'body', :method => :get}) {|params| {:body => params[:body], :headers => params[:headers], :status => 200}}") do

    Excon.stub({:body => 'body', :method => :get}) {|params| {:body => params[:body], :headers => params[:headers], :status => 200}}

    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:body => 'body', :method => :get, :path => '/content-length/100')

    tests('response.body').returns('body') do
      response.body
    end

    tests('response.headers').returns({'Host' => '127.0.0.1:9292'}) do
      response.headers
    end

    tests('response.status').returns(200) do
      response.status
    end

    Excon.stubs.pop

  end

  Excon.mock = false

  tests('mock = false') do
    with_rackup('basic.ru') do
      basic_tests
    end
  end

end
