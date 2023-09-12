require 'spec_helper'

describe Excon::Socket do
  let(:dns_resolver) { Resolv::DNS.new }
  let(:config_timeouts) { dns_resolver.instance_variable_get(:@config).instance_variable_get(:@timeouts) }
  let(:connection) { Excon.new('http://foo.com', dns_timeouts: 1) }

  before { allow(Resolv::DNS).to receive(:new).and_return(dns_resolver) }

  it 'passes the dns_timeouts to Resolv::DNS::Config' do
    connection.request

    expect(config_timeouts).to eql([1])
  end

  context 'when the DNS server takes too long to resolve' do
    include_context('test server', :webrick, 'dns_timeout.ru', before: :start, after: :stop)

    let(:dns_resolver) { Resolv::DNS.new(nameserver: '127.0.0.1') }

    it 'returns a Excon::Error::Socket' do
      expect { connection.request }.to raise_error(Excon::Error::Socket)
    end
  end
end
