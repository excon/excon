# frozen_string_literal: true

require_relative '../test_helper'

# A middleware can answer a request itself by setting params[:response] in
# request_call; excon then skips the network (so the host need not exist).
# These tests check excon doesn't mutate the body the middleware hands over.
class CannedResponseTest < Minitest::Test
  def setup
    @canned_body = +'canned'
    canned_body = @canned_body
    @middleware = Class.new(Excon::Middleware::Base) do
      define_method :request_call do |params|
        params[:response] = { body: canned_body, headers: {}, status: 200 }
        super(params)
      end
    end
  end

  def test_returns_canned_body
    response = Excon.get(
      'http://some-host.com/some-path',
      middlewares: [@middleware] + Excon.defaults[:middlewares]
    )

    assert_equal 'canned', response.body
    assert_equal 'canned', @canned_body
  end

  def test_yields_canned_body_to_response_block_without_mutating_it
    body = +''
    Excon.get(
      'http://some-host.com/some-path',
      middlewares: [@middleware] + Excon.defaults[:middlewares],
      response_block: ->(chunk, _remaining, _total) { body << chunk }
    )

    assert_equal 'canned', body
    # excon slices chunks off a copy, leaving the middleware's string intact
    assert_equal 'canned', @canned_body
  end
end
