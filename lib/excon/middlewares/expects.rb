module Excon
  module Middleware
    class Expects < Excon::Middleware::Base
      def after(datum)
        if datum.has_key?(:expects) && ![*datum[:expects]].include?(datum[:response][:status])
          raise(
            Excon::Errors.status_error(
              datum.reject {|key, value| key == :response},
              datum[:response]
            )
          )
        else
          @stack.after(datum)
        end
      end
    end
  end
end
