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

    tests('request body with block given').returns('body') do
      body = ''
      connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_bytes, total_bytes|
        body << chunk
      end
      body
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

    tests('request body with block given').returns('body') do
      body = ''
      connection.request(:body => 'body', :method => :get, :path => '/content-length/100') do |chunk, remaining_bytes, total_bytes|
        body << chunk
      end
      body
    end

    Excon.stubs.pop

  end

  tests("mismatched stub").raises(Excon::Errors::StubNotFound) do
    Excon.stub({:method => :post}, {:body => 'body'})
    Excon.get('http://127.0.0.1:9292/')
  end

  tests("stub({}, {:body => 'x' * (Excon::CHUNK_SIZE + 1)})") do
    connection = Excon.new('http://127.0.0.1:9292')
    Excon.stub({}, {:body => 'x' * (Excon::CHUNK_SIZE + 1)})

    test("with block") do
      chunks = []
      response = connection.request(:method => :get, :path => '/content-length/100') do |chunk, remaining_bytes, total_bytes|
        chunks << chunk
      end
      chunks == ['x' * Excon::CHUNK_SIZE, 'x']
    end
  end

  Excon.mock = false

  tests('mock = false') do
    with_rackup('basic.ru') do
      basic_tests
    end
  end

end
