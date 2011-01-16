require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler'

Bundler.require(:default, :development)

def local_file(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), *parts))
end

def with_rackup(configru = local_file('config.ru'))
  pid, w, r, e = Open4.popen4("rackup #{configru}")
  until e.gets =~ /HTTPServer#start:/; end
  yield
ensure
  Process.kill(9, pid)
end
