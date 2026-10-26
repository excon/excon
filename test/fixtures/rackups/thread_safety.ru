# Uses a local MatchData rather than =~ and Regexp.last_match: on JRuby, $~
# in this block belongs to the enclosing frame, which concurrent requests
# share, so one request could read another's id.
app = lambda do |env|
  match = %r{\A/id/([^/]+)/wait/([^/]+)\z}.match(env['PATH_INFO'])
  if %w[GET HEAD].include?(env['REQUEST_METHOD']) && match
    id, wait = match.captures
    sleep(wait.to_i)
    [200, { 'content-type' => 'text/plain' }, [id]]
  else
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end
end

run app
