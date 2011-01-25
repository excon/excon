require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler'

Bundler.require(:default, :development)

def rackup_path(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), 'rackups', *parts))
end

def with_rackup(name)
  pid, w, r, e = Open4.popen4("rackup #{rackup_path(name)}")
  until e.gets =~ /HTTPServer#start:/; end
  yield
ensure
  Process.kill(9, pid)
end
