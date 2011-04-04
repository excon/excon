with_rackup('thread_safety.ru') do
  Shindo.tests('Excon thread safety') do
    connection = Excon.new('http://127.0.0.1:9292')

    long_thread = Thread.new {
      response = connection.request(:method => 'GET', :path => '/id/1/wait/2')
      Thread.current[:success] = response.body == '1'
    }

    short_thread = Thread.new {
      response = connection.request(:method => 'GET', :path => '/id/2/wait/1')
      Thread.current[:success] = response.body == '2'
    }

    long_thread.join
    short_thread.join

    test('long_thread') do
      long_thread[:success]
    end

    test('short_thread') do
      short_thread[:success]
    end
  end
end
