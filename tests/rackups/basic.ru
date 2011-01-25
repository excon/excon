require 'sinatra'

class App < Sinatra::Base
  get '/content-length/:value' do |value|
    'x' * value.to_i
  end
end

run App
