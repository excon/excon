require 'spec_helper'

describe Excon::Connection do
  include_context('test server', :webrick, 'timeout.ru', before: :start, after: :stop)

  let(:read_timeout) { 60 }
  let(:conn) do
    Excon::Connection.new(host: '127.0.0.1',
                          hostname: '127.0.0.1',
                          nonblock: nonblock,
                          port: 9292,
                          scheme: 'http',
                          timeout: timeout,
                          read_timeout: read_timeout)
  end

  context "blocking connection" do
    let (:nonblock) { false }

    context 'when timeout is not set' do
      let(:timeout) { nil }
  
      it 'does not error' do
        expect(conn.request(:path => '/').status).to eq(200)
      end
    end

    context 'when timeout is not triggered' do
      let(:timeout) { 1 }

      it 'does not error' do
        expect(conn.request(:path => '/').status).to eq(200)        
      end
    end
  
    context 'when timeout is triggered' do
      let(:read_timeout) { 0.005 }
      let(:timeout) { 0.001 }
  
      it 'does not raise' do
        # raising a read timeout to keep tests fast
        expect { conn.request(:path => '/timeout') }.to raise_error(Excon::Error::Timeout, 'read timeout reached')
      end
    end
  end

  context "non-blocking connection" do
    let (:nonblock) { true }

    context 'when timeout is not set' do
      let(:timeout) { nil }
  
      it 'does not error' do
        expect(conn.request(:path => '/').status).to eq(200)        
      end
    end

    context 'when timeout is not triggered' do
      let(:timeout) { 1 }
  
      it 'does not error' do
        expect(conn.request(:path => '/').status).to eq(200)        
      end
    end
  
    context 'when timeout is triggered' do
      let(:timeout) { 0.001 }
  
      it 'returns a request Excon::Error::Timeout' do
        expect { conn.request(:path => '/timeout') }.to raise_error(Excon::Error::Timeout, 'request timeout reached')
      end
    end

    context 'when read timeout is triggered' do
      let(:read_timeout) { 0.001 }
      let(:timeout) { 0.005 }
  
      it 'returns a read Excon::Error::Timeout' do
        expect { conn.request(:path => '/timeout') }.to raise_error(Excon::Error::Timeout, 'read timeout reached')
      end
    end
  end
end
