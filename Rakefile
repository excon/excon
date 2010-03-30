require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "excon"
    gem.summary = %Q{EXtended http(s) CONnections}
    gem.description = %Q{speed, persistence, http(s)}
    gem.email = "wbeary@engineyard.com"
    gem.homepage = "http://github.com/geemus/excon"
    gem.authors = ["Wesley Beary"]
    # gem.add_development_dependency "shindo", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'shindo/rake'
Shindo::Rake.new

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "excon #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
