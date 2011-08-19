require 'sinatra'

class App < Sinatra::Base
  get '/' do
    'GET'
  end
  
  post '/' do
    'POST'
  end
  
  delete '/' do
    'DELETE'
  end
end

run App
