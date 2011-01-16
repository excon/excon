require File.expand_path('../test_helper', __FILE__)

Shindo.tests('gemspec') do
  tests('home page url') do
    returns(200) do
      profile_url = File.read(File.expand_path('../../excon.gemspec',__FILE__)).match(/s.homepage = '([^']+)'/)[1]
      Excon.get(profile_url).status
    end
  end
end
