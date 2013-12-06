Shindo.tests('Request Tests') do
  with_server('good') do

    tests('sets transfer-coding and connection options') do

      tests('without a :response_block') do
        request = nil

        returns('trailers, deflate, gzip', 'sets encoding options') do
          request = Marshal.load(
            Excon.get('http://127.0.0.1:9292/echo/request').body
          )

          request[:headers]['TE']
        end

        returns(true, 'TE added to Connection header') do
          request[:headers]['Connection'].include?('TE')
        end
      end

      tests('with a :response_block') do
        request = nil

        returns('trailers', 'does not set encoding options') do
          captures = capture_response_block do |block|
            Excon.get('http://127.0.0.1:9292/echo/request',
                      :response_block => block)
          end
          data = captures.map {|capture| capture[0] }.join
          request = Marshal.load(data)

          request[:headers]['TE']
        end

        returns(true, 'TE added to Connection header') do
          request[:headers]['Connection'].include?('TE')
        end
      end

    end

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

      tests('sends `Connection: close`') do
        returns(true, 'when :persistent => false') do
          request = Marshal.load(
            Excon.get('http://127.0.0.1:9292/echo/request',
                      :persistent => false).body
          )
          request[:headers]['Connection'].include?('close')
        end

        returns(false, 'not when :persistent => true') do
          request = Marshal.load(
            Excon.get('http://127.0.0.1:9292/echo/request',
                      :persistent => true).body
          )
          request[:headers]['Connection'].include?('close')
        end
      end

    end

  end
end
