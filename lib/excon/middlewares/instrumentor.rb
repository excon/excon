# frozen_string_literal: true
module Excon
  module Middleware
    class Instrumentor < Excon::Middleware::Base
      def self.valid_parameter_keys
        [
          :logger,
          :instrumentor,
          :instrumentor_name
        ]
      end

      def error_call(datum)
        if datum.has_key?(:instrumentor)
          datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.error", :error => datum[:error]) do
            @stack.error_call(datum)
          end
        else
          @stack.error_call(datum)
        end
      end

      def request_call(datum)
        if datum.has_key?(:instrumentor)
          if datum[:retries_remaining] < datum[:retry_limit]
            event_name = "#{datum[:instrumentor_name]}.retry"
          else
            event_name = "#{datum[:instrumentor_name]}.request"
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
          # pass the logger with the response, for LoggingInstrumentor
          params = datum.key?(:logger) ? datum[:response].merge(logger: datum[:logger]) : datum[:response]
          datum[:instrumentor].instrument("#{datum[:instrumentor_name]}.response", params) do
            @stack.response_call(datum)
          end
        else
          @stack.response_call(datum)
        end
      end
    end
  end
end
