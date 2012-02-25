require 'sinatra'

class App < Sinatra::Base
  before do
    auth ||= Rack::Auth::Basic::Request.new(request.env)
    user, pass = auth.provided? && auth.basic? && auth.credentials
    unless [user, pass] == ["test_user", "test_password"]
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  get('/content-length/:value') do |value|
    headers("Custom" => "Foo: bar")
    'x' * value.to_i
  end

  post('/body-sink') do
    request.body.read.size.to_s
  end
end

run App
