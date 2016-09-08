shared_examples_for 'a basic client' do |url = 'http://127.0.0.1:9292', opts = {}|
  # TODO: Ditch iterator and manually write a context for each set of options
    ([true, false] * 2).combination(2).to_a.uniq.each do |nonblock, persistent|
      context "when nonblock is #{nonblock} and persistent is #{persistent}" do
        opts = opts.merge(ssl_verify_peer: false, nonblock: nonblock, persistent: persistent)

        let(:conn) { Excon.new(url, opts) }

        context 'when :method is get and :path is /content-length/100' do
        describe '#request' do
          let(:response) do
            conn.request(method: :get, path: '/content-length/100')
          end

          it 'returns an Excon::Response' do
            expect(response).to be_instance_of Excon::Response
          end
          describe Excon::Response do
            describe '#status' do
              it 'returns 200' do
                  expect(response.status).to eq 200
              end
            end
          end
        end
      end
    end
  end
end
