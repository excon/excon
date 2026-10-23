require 'json'

app = lambda do |env|
  request = Rack::Request.new(env)
  response = Rack::Response.new([], 200, 'content-type' => 'text/plain')

  case [request.request_method, request.path_info]
  in ['GET' | 'HEAD', '/sets_cookie']
    response.set_cookie('chocolatechip', value: 'chunky', path: '/')
    response.redirect("#{request.base_url}/requires_cookie")
  in ['GET' | 'HEAD', '/sets_multi_cookie']
    response.set_cookie('chocolatechip', value: 'chunky', path: '/')
    response.set_cookie('thinmints', value: 'minty', path: '/')
    response.redirect("#{request.base_url}/requires_cookie")
  in ['GET' | 'HEAD', '/requires_cookie']
    if request.cookies['chocolatechip'] == 'chunky'
      response.write('ok')
    else
      response.write(JSON.pretty_generate(request.cookies))
    end
  else
    response.status = 404
    response.write('Not Found')
  end
  response.finish
end

run app
