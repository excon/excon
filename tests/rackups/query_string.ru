require 'sinatra'

class App < Sinatra::Base
  get('/query') do
    "query: " << request.query_string
  end
end

run App
