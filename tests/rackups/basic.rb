require 'sinatra'
require 'json'

class Basic < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('/') do
    'GET /'
  end

  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end

  get('/headers') do
    content_type :json
    request.env.select{|key, _| key.start_with? 'HTTP_'}.to_json
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

  get('/echo dirty') do
    echo
  end

  get('/foo') do
    'foo'
  end

  get('/bar') do
    'bar'
  end

  private

  def echo
    request.body.read
  end

end
