Shindo.tests('Request Tests') do
  with_server('good') do

    tests('persistent connections') do

      tests('with default :persistent => true') do
        connection = nil

        returns(['1', '2'], 'uses a persistent connection') do
          connection = Excon.new('http://127.0.0.1:9292', :persistent => true)
          2.times.map do
            connection.request(:method => :get, :path => '/echo/request_count').body
          end
        end

        returns(['3', '1', '2'], ':persistent => false resets connection') do
          ret = []
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count',
                                    :persistent => false).body
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count').body
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count').body
        end
      end

      tests('with default :persistent => false') do
        connection = nil

        returns(['1', '1'], 'does not use a persistent connection') do
          connection = Excon.new('http://127.0.0.1:9292', :persistent => false)
          2.times.map do
            connection.request(:method => :get, :path => '/echo/request_count').body
          end
        end

        returns(['1', '2', '3', '1'], ':persistent => true enables persistence') do
          ret = []
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count',
                                    :persistent => true).body
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count',
                                    :persistent => true).body
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count').body
          ret << connection.request(:method => :get,
                                    :path   => '/echo/request_count').body
        end
      end

    end

  end
end
