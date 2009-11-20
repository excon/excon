require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib/excon'))

Bundler.require_env(:test)

def local_file(*parts)
  File.expand_path(File.join(File.dirname(__FILE__), *parts))
end

def with_rackup(configru = local_file('config.ru'), rackup = local_file('..', 'bin', 'rackup'))
  pid, w, r, e = Open4.popen4("#{rackup} #{configru}")
  while `lsof -p #{pid} -P -i | grep ruby | grep TCP`.chomp.empty?; end
  yield
  Process.kill(9, pid)
end
