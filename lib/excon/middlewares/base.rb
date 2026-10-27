# frozen_string_literal: true
module Excon
  module Middleware
    class Base
      # Returns the list of parameters that this middleware uses that are valid
      # as arguments to `Connection#request` or `Connection#new`.
      def self.valid_parameter_keys
        []
      end

      # Checks the params passed to `Connection#request` (`params`) against
      # the full request (`datum`, with connection defaults merged in), and
      # warns with `Excon.display_warning` about combinations that won't work.
      def self.validate_request_params(params, datum)
      end

      def initialize(stack)
        @stack = stack
      end

      def error_call(datum)
        # do stuff
        @stack.error_call(datum)
      end

      def request_call(datum)
        # do stuff
        @stack.request_call(datum)
      end

      def response_call(datum)
        @stack.response_call(datum)
        # do stuff
      end
    end
  end
end
