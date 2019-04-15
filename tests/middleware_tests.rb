Shindo.tests('Excon middleware') do

  with_rackup('basic.ru', '0.0.0.0') do
    tests('succeeds without defining valid_parameter_keys') do
      class Middleware
        def initialize(stack)
          @stack = stack
        end
        def error_call(datum)
          @stack.error_call(datum)
        end
        def request_call(datum)
          @stack.request_call(datum)
        end
        def response_call(datum)
          @stack.response_call(datum)
        end
      end
      silence_warnings do
        Excon.get(
          'http://127.0.0.1:9292/content-length/100',
          :middlewares => Excon.defaults[:middlewares] + [Middleware]
        )
      end
    end
  end
end
