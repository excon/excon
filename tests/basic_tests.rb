with_rackup('basic.ru') do
  Shindo.tests('Excon basics') do
    basic_tests
  end
end

with_rackup('ssl.ru') do
  Shindo.tests('Excon basics (ssl)') do
    basic_tests('https://127.0.0.1:9443')
  end
end