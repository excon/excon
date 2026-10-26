require File.join(File.dirname(__FILE__), 'basic')

use Rack::Auth::Basic, 'Restricted Area' do |user, pass|
  [user, pass] == %w[test_user test_password]
end
run Basic
