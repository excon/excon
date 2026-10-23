require 'sinatra/base'

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('/no-timeout') do
    ''
  end

  get('/timeout') do
    sleep(0.1)
    ''
  end
end

run App
