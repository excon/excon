module Excon
  module Middleware
    class Decompress < Excon::Middleware::Base
      def response_call(datum)
        unless datum.has_key?(:response_block)
          case datum[:response][:headers]['Content-Encoding']
          when 'deflate'
            # assume inflate omits header
            datum[:response][:body] = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(datum[:response][:body])
          when 'gzip'
            datum[:response][:body] = Zlib::GzipReader.new(StringIO.new(datum[:response][:body])).read
          end
        end
        @stack.response_call(datum)
      end
    end
  end
end
