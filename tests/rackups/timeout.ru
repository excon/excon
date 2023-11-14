require 'sinatra'

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('/') do
    ''
  end

  get('/timeout') do
    sleep(2)
    ''
  end
end

run App
