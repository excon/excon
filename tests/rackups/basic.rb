require 'sinatra'

class Basic < Sinatra::Base
  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end

  post('/body-sink') do
    request.body.read.size.to_s
  end

  post('/echo') do
    echo
  end

  put('/echo') do
    echo
  end

  private

  def echo
    request.body.read
  end

end
