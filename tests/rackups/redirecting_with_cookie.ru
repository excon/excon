require 'sinatra/base'
require 'json'

class App < Sinatra::Base
  set :environment, :production
  enable :dump_errors

  get('/sets_cookie') do
    response.set_cookie("chocolatechip", value: "chunky", path: "/")
    redirect "/requires_cookie"
  end

  get('/requires_cookie') do
    cookie = request.cookies['chocolatechip']
    unless cookie.nil? || cookie != "chunky"
      "ok"
    else
      JSON.pretty_generate(headers)
    end
  end
  
  get('/sets_multi_cookie') do
    response.set_cookie("chocolatechip", value: "chunky", path: "/")
    response.set_cookie("thinmints", value: "minty", path: "/")
    redirect "/requires_cookie"
  end

  get('/requires_cookie') do
    if request.cookies['chocolatechip'] == "chunky" && request.cookies['thinmints'] == "minty" 
      "ok"
    else
      JSON.pretty_generate(headers)
    end
  end
end

run App
