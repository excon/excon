module Excon
  module Middleware
    class Idempotent < Excon::Middleware::Base
      def error_call(datum)
        if datum[:idempotent] && [Excon::Errors::Timeout, Excon::Errors::SocketError,
            Excon::Errors::HTTPStatusError].any? {|ex| datum[:error].kind_of?(ex) } && datum[:retries_remaining] > 1
          # reduces remaining retries, reset connection, and restart request_call
          datum[:retries_remaining] -= 1
          datum[:connection].reset
          datum.delete(:response)
          datum.delete(:error)
          datum[:connection].request(datum)
        else
          @stack.error_call(datum)
        end
      end
    end
  end
end
