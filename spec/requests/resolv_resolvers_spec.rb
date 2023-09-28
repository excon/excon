require 'spec_helper'

describe Excon::Socket do
  let(:dns_resolver) { Resolv::DNS.new }
  let(:resolv_resolver) { Resolv.new([Resolv::Hosts.new, dns_resolver]) }
  let(:config_timeouts) { dns_resolver.instance_variable_get(:@config).instance_variable_get(:@timeouts) }
  let(:connection) { Excon.new('http://foo.com', resolv_resolver: resolv_resolver) }

  before do
    dns_resolver.timeouts = 1
    allow(Resolv::DNS).to receive(:new).and_return(dns_resolver)
  end

  it 'resolv_resolver config reaches Resolv::DNS::Config' do
    connection.request

    expect(config_timeouts).to eql([1])
  end

  context 'when the DNS server is unreachable' do
    let(:dns_resolver) { Resolv::DNS.new(nameserver: ['127.0.0.1', '127.0.0.1']) }

    it 'returns a Excon::Error::Socket' do
      expect { connection.request }.to raise_error(Excon::Error::Socket)
    end
  end
end
