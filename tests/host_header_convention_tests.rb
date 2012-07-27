Shindo.tests('Excon host header convention') do

  before do
    Excon.stub({:method => :get}) { |params|
      {:body => params[:headers]['Host']}
    }
  end

  tests("An HTTP URL with a default port includes the port").returns("foo") do
    Excon.new('http://foo:80', :mock => true).request(:method => :get).body
  end

  tests("An HTTP URL with a non-default port includes the port").returns("foo:9292") do
    Excon.new('http://foo:9292', :mock => true).request(:method => :get).body
  end

  tests("An HTTPS URL with a non-default port includes the port").returns("foo") do
    Excon.new('https://foo:443', :mock => true).request(:method => :get).body
  end

  tests("An HTTPS URL with a non-default port includes the port").returns("foo:9443") do
    Excon.new('https://foo:9443', :mock => true).request(:method => :get).body
  end

  after do
    Excon.stubs.clear
  end

end
