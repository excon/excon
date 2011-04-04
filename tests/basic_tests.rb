with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    basic_tests
  end
end
