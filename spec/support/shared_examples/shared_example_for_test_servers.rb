shared_examples_for "a excon test server" do |plugin, file, bind|

    include_context("test server", plugin, file, bind ? { bind: bind } : {})

    it "returns an instance" do
      expect(@server).to be_instance_of Excon::Test::Server
    end

    it 'starts the server' do
      expect(@server.start).to be true
      expect(File.socket?(@server.bind.path)).to be true if @server.bind.scheme == 'unix'
    end

    it 'stops the server' do
      expect(@server.stop).to be true
      expect(File.exist?(@server.bind.path)).to be false if @server.bind.scheme == 'unix'
    end
end
