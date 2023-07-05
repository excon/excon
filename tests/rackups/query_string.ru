require 'sinatra'

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('/query') do
    "query: " << request.query_string
  end
end

run App
