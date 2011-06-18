require 'sinatra'

class App < Sinatra::Base
  get('/foo') do
    headers(
      "MixedCase-Header" => 'MixedCase',
      "UPPERCASE-HEADER" => 'UPPERCASE',
      "lowercase-header" => 'lowercase'
    )
    'primary content'
  end
end

run App
