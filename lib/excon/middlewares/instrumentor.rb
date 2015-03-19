module Excon
  module Middleware
    class Instrumentor < Excon::Middleware::Base
      def error_call(datum)
        if datum.has_key?(:instrumentor)
          datum[:instrumentor].instrument("error.#{datum[:instrumentor_name]}", :error => datum[:error])
        end
        @stack.error_call(datum)
      end

      def request_call(datum)
        if datum.has_key?(:instrumentor)
          if datum[:retries_remaining] < datum[:retry_limit]
            event_name = "retry.#{datum[:instrumentor_name]}"
          else
            event_name = "request.#{datum[:instrumentor_name]}"
          end
          datum[:instrumentor].instrument(event_name, datum) do
            @stack.request_call(datum)
          end
        else
          @stack.request_call(datum)
        end
      end

      def response_call(datum)
        if datum.has_key?(:instrumentor)
          datum[:instrumentor].instrument("response.#{datum[:instrumentor_name]}", datum[:response])
        end
        @stack.response_call(datum)
      end
    end
  end
end
