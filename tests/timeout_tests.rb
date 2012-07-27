with_rackup('timeout.ru') do
  Shindo.tests('read should timeout') do
    connection = Excon.new('http://127.0.0.1:9292')

    tests('hits read_timeout').raises(Excon::Errors::Timeout) do
      connection.request(:method => :get, :path => '/timeout', :read_timeout => 1)
    end

  end
end
