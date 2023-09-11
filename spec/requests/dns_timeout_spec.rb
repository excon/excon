require 'spec_helper'

describe Excon::Socket do
  include_context('test server', :webrick, 'dns_timeout.ru', before: :start, after: :stop)

  context 'when the DNS server takes too long to resolve' do
    let(:dns_resolver) { Resolv::DNS.new(nameserver_port: [['127.0.0.1', 4567]]) }

    before { allow(Resolv::DNS).to receive(:new).and_return(dns_resolver) }

    it 'returns a Resolv::ResolvError' do
      expect do
        connection = Excon.new('http://foo.com', dns_timeouts: 1)
        connection.request
      end.to raise_error(Excon::Error::Socket)
    end
  end
end
