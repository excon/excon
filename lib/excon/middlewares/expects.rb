module Excon
  module Middleware
    class Expects
      def initialize(app)
        @app = app
      end

      def call(datum)
        response_datum = @app.call(datum)

        if datum.has_key?(:expects) && ![*datum[:expects]].include?(response_datum[:status])
          raise(Excon::Errors.status_error(datum, Excon::Response.new(response_datum)))
        else
          response_datum
        end
      end
    end
  end
end
