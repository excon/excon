require 'spec_helper'

# The variable file should be renamed to something better - starbelly
shared_examples_for "a web server" do |plugin, file, bind_str = nil|
    plugin = plugin.to_sym unless plugin.is_a? Symbol

    if plugin == :unicorn && RUBY_PLATFORM == "java"
      before { skip("until unicorn supports jruby") }
    end

    abs_file = Object.send("#{plugin}_path", file)
    instance = nil
    args = { plugin => abs_file}
    args[:bind] = bind_str unless bind_str.nil?

    it "returns an instance" do
      instance = Excon::Test::Server.new(args)
      expect(instance).to be_instance_of Excon::Test::Server
    end
 
    it 'starts the server' do
      expect(instance.start).to be true
    end

    it 'stops the server' do
      expect(instance.stop).to be true
    end
end

describe Excon::Test::Server do
  context 'when webrick' do
    it_should_behave_like "a web server", :webrick, 'basic.ru'
  end

  context 'when unicorn' do
    it_should_behave_like "a web server", :unicorn, 'streaming.ru'
  end

  context "when unicorn is given a unix socket uri" do
    socket_uri = 'unix:///tmp/unicorn.socket'
    it_should_behave_like "a web server", :unicorn, 'streaming.ru', socket_uri
  end

  context 'when puma' do
    it_should_behave_like "a web server", :puma, 'streaming.ru'
  end

  context 'when executable' do
    it_should_behave_like "a web server", :exec, 'good.rb' 
  end
end
