# frozen_string_literal: true

require_relative '../test_helper'

# RedirectFollower re-issues the request to the Location of a 301, 302, 303,
# 307 or 308 response, until it gets another status or runs out of redirects.
# These tests use stubs, so nothing listens on the port.
class RedirectFollowerTest < Minitest::Test
  include WithoutProxyEnv

  def teardown
    Excon.stubs.clear
    super
  end

  def get(path)
    Excon.get(
      'http://127.0.0.1:9292',
      path: path,
      middlewares: Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower],
      mock: true
    )
  end

  def stub_redirect(path, location)
    Excon.stub({ path: path }, { headers: { 'Location' => location }, body: path, status: 301 })
  end

  def stub_ok(path)
    Excon.stub({ path: path }, { body: path, status: 200 })
  end

  def test_follows_absolute_location
    stub_redirect('/old', 'http://127.0.0.1:9292/new')
    stub_ok('/new')

    assert_equal '/new', get('/old').body
  end

  def test_follows_relative_location
    stub_redirect('/old', '/new')
    stub_ok('/new')

    assert_equal '/new', get('/old').body
  end

  def test_resolves_dot_segments_in_relative_location
    # ../bar/ is relative to /foo/baz/, so it resolves to /foo/bar/
    stub_redirect('/foo/baz/', '../bar/')
    stub_ok('/foo/bar/')

    assert_equal '/foo/bar/', get('/foo/baz/').body
  end

  def test_raises_on_redirect_loop
    stub_redirect('/old', 'http://127.0.0.1:9292/old')

    assert_raises(Excon::Errors::TooManyRedirects) { get('/old') }
  end

  def test_returns_redirect_without_location
    Excon.stub({ path: '/old' }, { body: 'no location', status: 302 })

    response = get('/old')

    assert_equal 302, response.status
    assert_equal 'no location', response.body
  end
end

# redirecting.ru answers POST /first with a 303 to /second, and GET /second
# with 'ok' only if the request has no body and no Content-Length (otherwise
# it dumps the request env as JSON).
class RedirectFollowerPostTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'redirecting.ru'

  def test_drops_body_and_content_length_when_303_turns_post_into_get
    response = Excon.post(
      'http://127.0.0.1:9292',
      path: '/first',
      middlewares: Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower],
      body: 'a=Some_content'
    )

    assert_equal 'ok', response.body
  end
end
