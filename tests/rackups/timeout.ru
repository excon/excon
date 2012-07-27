require 'sinatra'

class App < Sinatra::Base
  get('/timeout') do
    sleep(2)
  end
end

run App
