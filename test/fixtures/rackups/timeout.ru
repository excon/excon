app = lambda do |env|
  case [env['REQUEST_METHOD'], env['PATH_INFO']]
  in ['GET' | 'HEAD', '/no-timeout']
    [200, { 'content-type' => 'text/plain' }, ['']]
  in ['GET' | 'HEAD', '/timeout']
    sleep(0.1)
    [200, { 'content-type' => 'text/plain' }, ['']]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
