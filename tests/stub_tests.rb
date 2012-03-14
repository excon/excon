Shindo.tests('Excon stubs') do

  tests("missing stub").raises(Excon::Errors::StubNotFound) do
    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
    connection.request(:method => :get, :path => '/content-length/100')
  end

  tests("stub({})").raises(ArgumentError) do
    Excon.stub({})
  end

  tests("stub({}, {}) {}").raises(ArgumentError) do
    Excon.stub({}, {}) {}
  end

  tests("stub({:method => :get}, {:body => 'body', :status => 200})") do

    Excon.stub({:method => :get}, {:body => 'body', :status => 200})

    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
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

    tests('request body with response_block given').returns('body') do
      body = ''
      response_block = lambda do |chunk, remaining_bytes, total_bytes|
        body << chunk
      end
      connection.request(:method => :get, :path => '/content-length/100', :response_block => response_block)
      body
    end

    Excon.stubs.clear

  end

  tests("stub({:path => %r{/tests/(\S+)}}, {:body => $1, :status => 200})") do

    Excon.stub({:path => %r{/tests/(\S+)}}) do |params|
      {
        :body => params[:captures][:path].first,
        :status => 200
      }
    end

    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
    response = connection.request(:method => :get, :path => '/tests/test')

    tests('response.body').returns('test') do
      response.body
    end

    tests('response.headers').returns({}) do
      response.headers
    end

    tests('response.status').returns(200) do
      response.status
    end

    Excon.stubs.clear

  end

  tests("stub({:body => 'body', :method => :get}) {|params| {:body => params[:body], :headers => params[:headers], :status => 200}}") do

    Excon.stub({:body => 'body', :method => :get}) {|params| {:body => params[:body], :headers => params[:headers], :status => 200}}

    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
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

    tests('request body with response block given').returns('body') do
      body = ''
      response_block = lambda do |chunk, remaining_bytes, total_bytes|
        body << chunk
      end
      connection.request(:body => 'body', :method => :get, :path => '/content-length/100', :response_block => response_block)
      body
    end

    Excon.stubs.clear

  end

  tests("mismatched stub").raises(Excon::Errors::StubNotFound) do
    Excon.stub({:method => :post}, {:body => 'body'})
    Excon.get('http://127.0.0.1:9292/', :mock => true)
  end

  Excon.stubs.clear

  tests("stub({}, {:body => 'x' * (Excon::CHUNK_SIZE + 1)})") do
    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
    Excon.stub({}, {:body => 'x' * (Excon::CHUNK_SIZE + 1)})

    test("with response_block") do
      chunks = []
      response_block = lambda do |chunk, remaining_bytes, total_bytes|
        chunks << chunk
      end
      connection.request(:method => :get, :path => '/content-length/100', :response_block => response_block)
      chunks == ['x' * Excon::CHUNK_SIZE, 'x']
    end
  end

  Excon.stubs.clear

  tests("stub({}, {:status => 404, :body => 'Not Found'}") do

    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
    Excon.stub({}, {:status => 404, :body => 'Not Found'})

    tests("request(:expects => 200, :method => :get, :path => '/')").raises(Excon::Errors::NotFound) do
      connection.request(:expects => 200, :method => :get, :path => '/')
    end

    test("request(:expects => 200, :method => :get, :path => '/') with block does not invoke the block since it raises an error") do
      block_called = false
      begin
        response_block = lambda do |_,_,_|
          block_called = true
        end
        connection.request(:expects => 200, :method => :get, :path => '/', :response_block => response_block)
      rescue Excon::Errors::NotFound
      end
      !block_called
    end

    Excon.stubs.clear

  end

  tests('mock = false') do
    with_rackup('basic.ru') do
      basic_tests
    end
  end

end
