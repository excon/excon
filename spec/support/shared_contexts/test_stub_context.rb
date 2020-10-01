shared_context "stubs" do 
  before do
    @original_mock = Excon.defaults[:mock]
    Excon.defaults[:mock] = true
  end

  after do
    Excon.defaults[:mock] = @original_mock
    Excon.stubs.clear
  end
end