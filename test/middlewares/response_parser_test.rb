# frozen_string_literal: true

require_relative '../test_helper'

# excon reads the response before any middleware's response_call, so a
# middleware sees it wherever it is in the stack. ResponseParser, which used
# to read it, now does nothing, but stays in the default middlewares.
class ResponseParserTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'basic.ru'

  # Records the response it sees before calling the rest of the stack.
  class SeesResponse < Excon::Middleware::Base
    class << self
      attr_accessor :seen
    end

    def response_call(datum)
      self.class.seen = datum[:response]
      super
    end
  end

  def setup
    SeesResponse.seen = nil
  end

  def test_response_parser_still_in_default_middlewares
    # code such as VCR's excon hook inserts its middleware after it
    assert_includes Excon.defaults[:middlewares], Excon::Middleware::ResponseParser
  end

  def test_first_middleware_sees_response_before_rest_of_stack
    Excon.get('http://127.0.0.1:9292/foo', middlewares: [SeesResponse] + Excon.defaults[:middlewares])

    # basic.ru's /foo responds 'foo'
    assert_equal 200, SeesResponse.seen[:status]
    assert_equal 'foo', SeesResponse.seen[:body]
  end

  def test_middleware_after_response_parser_sees_response
    middlewares = Excon.defaults[:middlewares].dup
    middlewares.insert(middlewares.index(Excon::Middleware::ResponseParser) + 1, SeesResponse)
    Excon.get('http://127.0.0.1:9292/foo', middlewares: middlewares)

    assert_equal 'foo', SeesResponse.seen[:body]
  end

  def test_stack_without_response_parser_reads_response
    middlewares = Excon.defaults[:middlewares] - [Excon::Middleware::ResponseParser]
    response = Excon.get('http://127.0.0.1:9292/foo', middlewares: middlewares)

    assert_equal 200, response.status
    assert_equal 'foo', response.body
  end
end
