module Excon
  module Middleware
    class Idempotent < Excon::Middleware::Base
      def error_call(datum)
        if datum[:idempotent]
          if datum.has_key?(:request_block)
            Excon.display_warning('Excon requests with a :request_block can not be :idempotent.')
            datum[:idempotent] = false
          end
          if datum.has_key?(:pipeline)
            Excon.display_warning("Excon requests can not be :idempotent when pipelining.")
            datum[:idempotent] = false
          end
        end

        if datum[:idempotent] && [Excon::Errors::Timeout, Excon::Errors::SocketError,
            Excon::Errors::HTTPStatusError].any? {|ex| datum[:error].kind_of?(ex) } && datum[:retries_remaining] > 1
          # reduces remaining retries, reset connection, and restart request_call
          datum[:retries_remaining] -= 1
          connection = datum.delete(:connection)
          datum.reject! {|key, _| !Excon::VALID_REQUEST_KEYS.include?(key) }
          connection.request(datum)
        else
          @stack.error_call(datum)
        end
      end
    end
  end
end
