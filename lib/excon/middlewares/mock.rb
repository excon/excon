module Excon
  module Middleware
    class Mock < Excon::Middleware::Base
      def request_call(datum)
        if datum[:mock]
          # convert File/Tempfile body to string before matching:
          unless datum[:body].nil? || datum[:body].is_a?(String)
           if datum[:body].respond_to?(:binmode)
             datum[:body].binmode
           end
           if datum[:body].respond_to?(:rewind)
             datum[:body].rewind
           end
           datum[:body] = datum[:body].read
          end

          if response = Excon.stub_for(datum)
            datum[:response] = {
              :body       => '',
              :headers    => {},
              :status     => 200,
              :remote_ip  => '127.0.0.1'
            }

            stub_datum = case response
            when Proc
              response.call(datum)
            else
              response
            end

            datum[:response].merge!(stub_datum.reject {|key,value| key == :headers})
            if stub_datum.has_key?(:headers)
              datum[:response][:headers].merge!(stub_datum[:headers])
            end

            if datum[:expects] && ![*datum[:expects]].include?(datum[:response][:status])
              # don't pass stuff into a block if there was an error
            elsif datum.has_key?(:response_block) && datum[:response].has_key?(:body)
              body = datum[:response][:body]
              datum[:response][:body] = '' # matches with non-mocked streaming behavior
              content_length = remaining = body.bytesize
              i = 0
              while i < body.length
                datum[:response_block].call(body[i, datum[:chunk_size]], [remaining - datum[:chunk_size], 0].max, content_length)
                remaining -= datum[:chunk_size]
                i += datum[:chunk_size]
              end
            end
          else
            # if we reach here no stubs matched
            raise(Excon::Errors::StubNotFound.new('no stubs matched ' << datum.inspect))
          end
        end

        @stack.request_call(datum)
      end
    end
  end
end
