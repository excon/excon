module Excon
  module Middleware
    class Instrumentor
      def initialize(app)
        @app = app
      end

      def call(datum)
        if datum.has_key?(:instrumentor)
          if datum[:retries_remaining] < datum[:retry_limit]
            event_name = "#{datum[:instrumentor_name]}.retry"
          else
            event_name = "#{datum[:instrumentor_name]}.request"
          end
          response_datum = datum[:instrumentor].instrument(event_name, datum) do
            @app.call(datum)
          end
          datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.response", response_datum)
          response_datum
        else
          @app.call(datum)
        end
      end
    end
  end
end
