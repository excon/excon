require 'spec_helper'

describe Excon::Socket do
  let(:dns_resolver) { Resolv::DNS.new }
  let(:resolv_resolver) { Resolv.new([Resolv::Hosts.new, dns_resolver]) }
  let(:config_timeouts) { dns_resolver.instance_variable_get(:@config).instance_variable_get(:@timeouts) }
  let(:connection) { Excon.new('http://google.com', resolv_resolver: resolv_resolver) }
  let(:custom_resolver_factory) do
    Class.new do
      def self.create_resolver
        dns_resolver = Resolv::DNS.new
        dns_resolver.timeouts = 1
        Resolv.new([dns_resolver])
      end
    end
  end

  before do
    dns_resolver.timeouts = 1
    allow(Resolv::DNS).to receive(:new).and_return(dns_resolver)
  end

  around do |example|
    orig_defaults = Excon.defaults.dup
    Excon.defaults = Excon.defaults.merge(resolver_factory: custom_resolver_factory).freeze
    example.run
  ensure
    Excon.defaults = orig_defaults
  end

  it 'resolv_resolver config reaches Resolv::DNS::Config' do
    connection.connect

    expect(config_timeouts).to eql([1])
  end

  it 'does not use the custom resolver factory' do
    expect(custom_resolver_factory).not_to receive(:create_resolver)

    connection.connect
  end

  it 'does not use the default resolver factory' do
    expect(Excon::ResolverFactory).not_to receive(:create_resolver)

    connection.connect
  end

  context 'when the DNS server is unreachable' do
    let(:dns_resolver) { Resolv::DNS.new(nameserver: ['127.0.0.1', '127.0.0.1']) }

    it 'returns a Excon::Error::Socket' do
      expect { connection.request }.to raise_error(Excon::Error::Socket)
    end
  end

  context 'without resolv_resolver' do
    let(:connection) { Excon.new('http://google.com') }

    it 'uses the configured resolver factory' do
      expect(custom_resolver_factory).to receive(:create_resolver).once.and_call_original

      connection.connect
    end

    it 'does not use the default resolver factory' do
      expect(Excon::ResolverFactory).not_to receive(:create_resolver)

      connection.connect
    end
  end
end
