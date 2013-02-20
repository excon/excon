module Excon
  module Middleware
    class Expects < Excon::Middleware::Base
      def response_call(datum)
        if datum.has_key?(:expects) && ![*datum[:expects]].include?(datum[:response][:status])
          error_datum = datum.dup
          response_datum = error_datum.delete(:response)
          raise(
            Excon::Errors.status_error(error_datum, response_datum)
          )
        else
          @stack.response_call(datum)
        end
      end
    end
  end
end
