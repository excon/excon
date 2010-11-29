require 'rubygems'
require 'tach'

Tach.meter(1_000) do
  tach('concat') do
    path = 'path'
    path = '/' << path
  end
  tach('insert') do
    path = 'path'
    path.insert(0, '/')
  end
end

# +--------+----------+
# | tach   | total    |
# +--------+----------+
# | concat | 0.000797 |
# +--------+----------+
# | insert | 0.000871 |
# +--------+----------+