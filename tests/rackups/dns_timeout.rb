require 'sinatra'

class App < Sinatra::Base
  set :environment, :production
  set :port, 53
  enable :dump_errors

  get('/') do
    sleep(2)
    ''
  end
end
