disable_system_gems

only :test do
  gem 'shindo'
  gem 'open4'
end

only :test_server do
  gem 'sinatra', :require_as => 'sinatra/base'
end

only :benchmarks do
  gem 'eventmachine'
end
