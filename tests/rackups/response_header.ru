require 'sinatra'

class App < Sinatra::Base
  get('/foo') do
    headers(
      "Content-Type" => 'text/html',
      "CUSTOM-HEADER" => 'foo',
      "lowercase-header" => 'bar'
    )
    'primary content'
  end
end

run App
