require 'sinatra'

class App < Sinatra::Base
  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end

  post('/body-sink') do
    request.body.read.size.to_s
  end
end

run App
