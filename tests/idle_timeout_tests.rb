Shindo.tests('Idle Timeout Tests') do
  with_server('good') do

    tests(':nonblock => true') do
      connection = nil

      returns(['1', '2']) do
        connection = Excon.new('http://127.0.0.1:9292', :persistent => true)
        2.times.map { connection.get(:path => '/content-length/idle_timeout').body }
      end

      returns('1') do
        sleep 0.5 # give server time to close socket
        connection.get(:path => '/content-length/idle_timeout').body
      end
    end

    # i.e. no detection of a closed socket
    tests(':nonblock => false') do

      tests('with short request') do
        connection = nil

        returns(['1', '2']) do
          connection = Excon.new('http://127.0.0.1:9292', :persistent => true,
                                 :nonblock => false)
          2.times.map { connection.get(:path => '/content-length/idle_timeout').body }
        end

        # the write is short enough (i.e. a simple GET) not to raise an error.
        # EOFError is raised when we call socket.readline to parse the response.
        returns(EOFError) do
          sleep 0.5 # give server time to close socket
          begin
            connection.get(:path => '/content-length/idle_timeout')
          rescue Excon::Errors::SocketError => err
            err.socket_error.class
          end
        end
      end

      tests('with long request') do
        connection = nil

        returns(['1', '2']) do
          connection = Excon.new('http://127.0.0.1:9292', :persistent => true,
                                 :nonblock => false)
          2.times.map { connection.get(:path => '/content-length/idle_timeout').body }
        end

        # the write is long enough to raise a Broken Pipe error
        returns(Errno::EPIPE) do
          sleep 0.5 # give server time to close socket
          begin
            connection.get(
              :path => '/content-length/idle_timeout',
              :body => 'x' * 100
            )
          rescue Excon::Errors::SocketError => err
            err.socket_error.class
          end
        end
      end
    end

  end
end
