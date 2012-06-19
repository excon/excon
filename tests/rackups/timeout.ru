require 'sinatra'

class App < Sinatra::Base
  get('/timeout') do
    sleep(1)
  end
end

run App
