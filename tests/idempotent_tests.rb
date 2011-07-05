Shindo.tests('Excon request idempotencey') do
  Excon.mock = true

  tests("Non-idempotent call with an erroring socket").raises(Excon::Errors::SocketError) do
    Excon.stub({:method => :get}) { |params|
      run_count += 1
      if run_count < 4 # First 3 calls fail.
        raise Excon::Errors::SocketError.new(Exception.new "Mock Error")
      else
        {:body => params[:body], :headers => params[:headers], :status => 200}
      end
    }

    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:method => :get, :path => '/some-path')
  end

  Excon.stubs.pop

  tests("Idempotent request with socket erroring first 3 times").returns(200) do
    run_count = 0
    Excon.stub({:method => :get}) { |params|
      run_count += 1
      if run_count <= 3 # First 3 calls fail.
        raise Excon::Errors::SocketError.new(Exception.new "Mock Error")
      else
        {:body => params[:body], :headers => params[:headers], :status => 200}
      end
    }

    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:method => :get, :idempotent => true, :path => '/some-path')
    response.status
  end

  Excon.stubs.pop

  tests("Idempotent request with socket erroring first 5 times").raises(Excon::Errors::SocketError) do
    run_count = 0
    Excon.stub({:method => :get}) { |params|
      run_count += 1
      if run_count <= 5 # First 5 calls fail.
        raise Excon::Errors::SocketError.new(Exception.new "Mock Error")
      else
        {:body => params[:body], :headers => params[:headers], :status => 200}
      end
    }

    connection = Excon.new('http://127.0.0.1:9292')
    response = connection.request(:method => :get, :idempotent => true, :path => '/some-path')
    response.status
  end

  Excon.stubs.pop
  Excon.mock = false
end
