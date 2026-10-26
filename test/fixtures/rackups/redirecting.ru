require 'json'

app = lambda do |env|
  request = Rack::Request.new(env)

  case [request.request_method, request.path_info]
  in ['POST', '/first']
    [303, { 'location' => "#{request.base_url}/second" }, []]
  in ['GET' | 'HEAD', '/second']
    post_body = request.body.read
    if post_body == '' && env['CONTENT_LENGTH'].nil?
      [200, { 'content-type' => 'text/plain' }, ['ok']]
    else
      [200, { 'content-type' => 'application/json' }, [JSON.pretty_generate(env)]]
    end
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
