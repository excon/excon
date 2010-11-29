require 'rubygems'
require 'tach'

CRLF = "\r\n"

Tach.meter(1_000_000) do
  tach('constant') do
    '' << CRLF
  end
  tach('string') do
    '' << "\r\n"
  end
end

# +----------+----------+
# | tach     | total    |
# +----------+----------+
# | constant | 0.813338 |
# +----------+----------+
# | string   | 0.900186 |
# +----------+----------+