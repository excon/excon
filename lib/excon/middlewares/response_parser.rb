module Excon
  module Middleware
    class ResponseParser < Excon::Middleware::Base
      def response_call(datum)
        unless datum.has_key?(:response)
          datum = Excon::Response.parse(datum[:connection].send(:socket), datum)

          # only requests without a :response_block add 'deflate, gzip' to the TE header.
          unless datum[:response_block]
            if key = datum[:response][:headers].keys.detect {|k| k.casecmp('Transfer-Encoding') == 0 }
              encodings = Utils.split_header_value(datum[:response][:headers][key])
              if encoding = encodings.last
                if encoding.casecmp('deflate') == 0
                  # assume inflate omits header
                  datum[:response][:body] = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(datum[:response][:body])
                  encodings.pop
                elsif encoding.casecmp('gzip') == 0 || encoding.casecmp('x-gzip') == 0
                  datum[:response][:body] = Zlib::GzipReader.new(StringIO.new(datum[:response][:body])).read
                  encodings.pop
                end
                datum[:response][:headers][key] = encodings.join(', ')
              end
            end
          end
        end
        @stack.response_call(datum)
      end
    end
  end
end
