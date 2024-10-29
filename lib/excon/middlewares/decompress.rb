# frozen_string_literal: true

module Excon
  module Middleware
    class Decompress < Excon::Middleware::Base
      INFLATE_ZLIB_OR_GZIP  = 47 # Zlib::MAX_WBITS + 32
      INFLATE_RAW           = -15 # Zlib::MAX_WBITS * -1

      def request_call(datum)
        unless datum.key?(:response_block)
          key = datum[:headers].keys.detect { |k| k.to_s.casecmp?('Accept-Encoding') } || 'Accept-Encoding'
          datum[:headers][key] = 'deflate, gzip' if datum[:headers][key].to_s.empty?
        end
        @stack.request_call(datum)
      end

      def response_call(datum)
        body = datum[:response][:body]
        if !(datum.key?(:response_block) || body.nil? || body.empty?) &&
           (key = datum[:response][:headers].keys.detect { |k| k.casecmp?('Content-Encoding') })
          encodings = Utils.split_header_value(datum[:response][:headers][key])
          if encodings&.last&.casecmp?('deflate')
            datum[:response][:body] = begin
              Zlib::Inflate.new(INFLATE_ZLIB_OR_GZIP).inflate(body)
            rescue Zlib::DataError # fallback to raw on error
              Zlib::Inflate.new(INFLATE_RAW).inflate(body)
            end
            encodings.pop
          elsif encodings&.last&.casecmp?('gzip') || encodings&.last&.casecmp?('x-gzip')
            datum[:response][:body] = Zlib::GzipReader.new(StringIO.new(body)).read
            encodings.pop
          end
          datum[:response][:headers][key] = encodings.join(', ')
        end
        @stack.response_call(datum)
      end
    end
  end
end
