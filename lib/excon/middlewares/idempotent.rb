# frozen_string_literal: true
require 'set'

module Excon
  module Middleware
    class Idempotent < Excon::Middleware::Base
      def self.valid_parameter_keys
        [
          :idempotent,
          :retries_remaining,
          :retry_errors,
          :retry_interval,
          :retry_limit
        ]
      end

      # Retry options only take effect on :idempotent requests. Only the
      # request's own params are checked, as a connection may set retry
      # options for the requests on it that are :idempotent.
      def self.validate_request_params(params, datum)
        return if datum[:idempotent]

        retry_keys = params.keys & %i[retry_errors retry_interval retry_limit]
        return if retry_keys.empty?

        Excon.display_warning(
          "Excon request keys #{retry_keys.map(&:inspect).join(', ')} have no effect unless the request is :idempotent"
        )
      end

      def request_call(datum)
        datum[:retries_remaining] ||= datum[:retry_limit]
        @stack.request_call(datum)
      end

      def error_call(datum)
        if datum[:idempotent]
          if datum.has_key?(:request_block)
            if datum[:request_block].respond_to?(:rewind)
              datum[:request_block].rewind
            else
              Excon.display_warning('Excon requests with a :request_block must implement #rewind in order to be :idempotent.')
              datum[:idempotent] = false
            end
          end
          if datum.has_key?(:response_block) && datum[:response_block].respond_to?(:rewind)
            datum[:response_block].rewind
          end
          if datum.has_key?(:pipeline)
            Excon.display_warning("Excon requests can not be :idempotent when pipelining.")
            datum[:idempotent] = false
          end
        end

        if datum[:idempotent] && datum[:retry_errors].any? {|ex| datum[:error].kind_of?(ex) } && datum[:retries_remaining] > 1

          sleep(datum[:retry_interval]) if datum[:retry_interval]

          # reduces remaining retries, reset connection, and restart request_call
          datum[:retries_remaining] -= 1
          connection = datum.delete(:connection)
          valid_keys = Set.new(connection.valid_request_keys(datum[:middlewares]))
          datum.select! {|key, _| valid_keys.include?(key) }
          connection.request(datum)
        else
          @stack.error_call(datum)
        end
      end
    end
  end
end
