require 'sinatra'

class Basic < Sinatra::Base
  get('/status/:status') do |status|
    respond_with(status)
  end

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

  def respond_with(code)
    status code.to_i
    body "Requested status #{code}"
  end
end
