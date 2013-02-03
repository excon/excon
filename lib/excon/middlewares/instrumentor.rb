module Excon
  module Middleware
    class Instrumentor < Excon::Middleware::Base
      def before(datum)
        if datum.has_key?(:instrumentor)
          if datum[:retries_remaining] < datum[:retry_limit]
            event_name = "#{datum[:instrumentor_name]}.retry"
          else
            event_name = "#{datum[:instrumentor_name]}.request"
          end
          datum[:instrumentor].instrument(event_name, datum) do
            @stack.before(datum)
          end
        else
          @stack.before(datum)
        end
      end

      def after(datum)
        if datum.has_key?(:instrumentor)
          datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.response", datum[:response])
        end
        @stack.after(datum)
      end
    end
  end
end
