# frozen_string_literal: true
module Excon
  module Middleware
    # Does nothing: excon now reads the response before any middleware's
    # response_call. Kept in the default middlewares because existing code
    # finds its place in the stack (e.g. VCR inserts its middleware after it).
    class ResponseParser < Excon::Middleware::Base
    end
  end
end
