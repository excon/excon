module Excon
  module Middleware
    class ResponseProcessor < Excon::Middleware::Base
      def response_call(datum)
        if !datum.has_key?(:response)
          datum = Excon::Response.parse(datum[:connection].send(:socket), datum)
        elsif datum.has_key?(:response_block) && !datum[:response][:body].empty?
          # push non-parsed response through response_block, if provided
          content_length = remaining = datum[:response][:body].bytesize
          while remaining > 0
            datum[:response_block].call(datum[:response][:body].slice!(0, [datum[:chunk_size], remaining].min), [remaining - datum[:chunk_size], 0].max, content_length)
            remaining -= datum[:chunk_size]
          end
        end
        @stack.response_call(datum)
      end
    end
  end
end
