require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    basic_tests
  end
end
