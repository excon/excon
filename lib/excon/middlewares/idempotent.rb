module Excon
  module Middleware
    class Idempotent < Excon::Middleware::Base
      def request_call(datum)
        super
      rescue => error
        if datum[:idempotent] && [Excon::Errors::Timeout, Excon::Errors::SocketError,
            Excon::Errors::HTTPStatusError].any? {|ex| error.kind_of?(ex) } && datum[:retries_remaining] > 1
          # reduces remaining retries, reset connection, and restart request_call
          datum[:retries_remaining] -= 1
          datum[:connection].reset
          datum[:stack].request_call(datum)
        else
          raise(error)
        end
      end
    end
  end
end
