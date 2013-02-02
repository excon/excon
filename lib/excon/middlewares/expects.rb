module Excon
  module Middleware
    class Expects
      def initialize(stack)
        @stack = stack
      end

      def call(datum)
        datum = @stack.call(datum)

        if datum.has_key?(:expects) && ![*datum[:expects]].include?(datum[:response][:status])
          raise(
            Excon::Errors.status_error(
              datum.reject {|key, value| key == :response},
              datum[:response]
            )
          )
        else
          datum
        end
      end
    end
  end
end
