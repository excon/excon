shared_context "stubs" do 
  before do
    @original_defaults = Excon.defaults
    Excon.defaults = Excon.defaults.merge(mock: true)
  end

  after do
    Excon.defaults = @original_defaults
    Excon.stubs.clear
  end
end