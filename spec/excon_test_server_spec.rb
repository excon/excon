require 'spec_helper'

describe Excon::Test::Server do
  context 'when rackup' do
    it 'starts a new a app' do
      instance = Excon::Test::Server.new(rackup: rackup_path('basic.ru'),  bind: '127.0.0.1')
      expect(instance).to be_a(Excon::Test::Server)
      expect(instance.start).to be true
      expect(instance.stop).to be true
    end
  end
end
