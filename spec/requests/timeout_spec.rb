require 'spec_helper'

describe Excon::Connection do
  include_context('test server', :webrick, 'basic.ru', before: :start, after: :stop)

  let(:conn) do
    Excon::Connection.new(host: '127.0.0.1',
                          hostname: '127.0.0.1',
                          nonblock: nonblock,
                          port: 9292,
                          scheme: 'http',
                          timeout: timeout)
  end

  context "blocking connection" do
    let (:nonblock) { false }

    context 'when timeout is not triggered' do 
      let(:timeout) { 120 }

      include_examples 'a basic client'
    end
  
    context 'when timeout is triggered' do
      let(:timeout) { 0.001 }

      it 'does not error' do
        expect(conn.request(:path => '/sloth').status).to eq(200)
      end
    end
  end

  context "non-blocking connection" do
    let (:nonblock) { true }

    context 'when timeout is not triggered' do
      let(:timeout) { 120 }
  
      include_examples 'a basic client'
    end
  
    context 'when timeout is triggered' do
      let(:timeout) { 0.001 }
  
      it 'returns a Excon::Error::Timeout' do
        expect { conn.request(:path => '/sloth') }.to raise_error(Excon::Error::Timeout)
      end
    end
  end
end
