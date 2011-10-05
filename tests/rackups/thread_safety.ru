require 'sinatra'

require 'rack/head' # workaround for rbx thread safety issue (most likely autoload related)

class App < Sinatra::Base
  get('/id/:id/wait/:wait') do |id, wait|
    sleep(wait.to_i)
    id.to_s
  end
end

run App
