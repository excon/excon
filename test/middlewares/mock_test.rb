# frozen_string_literal: true

require_relative '../test_helper'

# With mock: true, the Mock middleware (a default) answers a request from the
# first stub (newest first) whose request params all match, without touching
# the network, so none of these hosts need to exist. A stub's response is
# either a hash or a block called with the request params. A request with no
# matching stub raises StubNotFound, unless allow_unstubbed_requests is set.
module MockTestHelpers
  def teardown
    Excon.stubs.clear
    super
  end

  private

  def connection
    Excon.new('http://127.0.0.1:9292', mock: true)
  end

  # Returns the chunks a request yields to a :response_block.
  def collect_chunks(**request_params)
    chunks = []
    connection.request(**request_params, response_block: ->(chunk, _remaining, _total) { chunks << chunk })
    chunks
  end

  def request_with_empty_response_block(**request_params)
    connection.request(**request_params, response_block: ->(_, _, _) {})
  end
end

class MockStubTest < Minitest::Test
  include WithoutProxyEnv
  include MockTestHelpers

  def test_stub_without_response_raises
    assert_raises(ArgumentError) { Excon.stub({}) }
  end

  def test_stub_with_both_response_and_block_raises
    assert_raises(ArgumentError) { Excon.stub({}, {}) { nil } }
  end

  def test_request_without_stub_raises
    assert_raises(Excon::Errors::StubNotFound) do
      connection.request(method: :get, path: '/content-length/100')
    end
  end

  def test_request_not_matching_stub_raises
    Excon.stub({ method: :post }, { body: 'body' })

    assert_raises(Excon::Errors::StubNotFound) do
      Excon.get('http://127.0.0.1:9292/', mock: true)
    end
  end

  def test_stub_returns_response_params
    Excon.stub({ method: :get }, { body: 'body', status: 200 })

    response = connection.request(method: :get, path: '/content-length/100')

    assert_equal 'body', response.body
    assert_equal({}, response.headers)
    assert_equal 200, response.status
  end

  def test_stub_yields_body_to_response_block
    Excon.stub({ method: :get }, { body: 'body', status: 200 })

    assert_equal ['body'], collect_chunks(method: :get, path: '/content-length/100')
  end

  def test_stub_body_is_empty_with_response_block
    Excon.stub({ method: :get }, { body: 'body', status: 200 })

    response = request_with_empty_response_block(method: :get, path: '/content-length/100')

    assert_equal '', response.body
  end

  def test_stub_matches_file_body_against_its_contents
    file_path = data_path('xs')
    Excon.stub({ body: File.read(file_path), method: :get }, { status: 200 })

    response = File.open(file_path) do |file|
      connection.request(body: file, method: :get, path: '/')
    end

    assert_equal 200, response.status
  end

  def test_request_with_non_string_body_raises
    Excon.stub({ body: 42, method: :get }, { status: 200 })

    assert_raises(Excon::Errors::InvalidStub) do
      connection.request(body: 42, method: :get, path: '/')
    end
  end

  def test_long_body_is_yielded_in_chunks
    Excon.stub({}, { body: 'x' * (Excon::DEFAULT_CHUNK_SIZE + 1) })

    chunks = collect_chunks(method: :get, path: '/content-length/100')

    assert_equal 2, chunks.length
    assert_equal 'x' * Excon::DEFAULT_CHUNK_SIZE, chunks[0]
    assert_equal 'x', chunks[1]
  end

  def test_long_body_is_empty_with_response_block
    Excon.stub({}, { body: 'x' * (Excon::DEFAULT_CHUNK_SIZE + 1) })

    response = request_with_empty_response_block(method: :get, path: '/content-length/100')

    assert_equal '', response.body
  end

  def test_unexpected_status_raises_with_response
    Excon.stub({}, { status: 404, body: 'Not Found' })

    error = assert_raises(Excon::Errors::NotFound) do
      connection.request(expects: 200, method: :get, path: '/')
    end

    assert_instance_of Excon::Response, error.response
  end

  def test_unexpected_status_does_not_call_response_block
    Excon.stub({}, { status: 404, body: 'Not Found' })

    assert_raises(Excon::Errors::NotFound) do
      connection.request(
        expects: 200, method: :get, path: '/', response_block: proc { flunk 'response_block was called' }
      )
    end
  end
end

# A stub's :url is split into host, path, port, query and scheme (and an
# Authorization header for any userinfo), each matched separately.
class MockStubUrlTest < Minitest::Test
  include WithoutProxyEnv
  include MockTestHelpers

  def test_url_without_trailing_slash_matches_request_without_it
    Excon.stub({ url: 'http://example.com' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com', mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_without_trailing_slash_matches_request_with_it
    Excon.stub({ url: 'http://example.com' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com/', mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_query_matches_query_in_url
    Excon.stub({ url: 'http://example.com?foo=bar' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com?foo=bar', mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_query_matches_query_hash
    Excon.stub({ url: 'http://example.com?foo=bar' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com', query: { 'foo' => 'bar' }, mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_escaped_query_matches_query_in_url
    Excon.stub({ url: 'http://example.com?a=b+c' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com?a=b+c', mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_escaped_query_matches_query_hash
    # the hash value is escaped, so 'b c' becomes 'b+c'
    Excon.stub({ url: 'http://example.com?a=b+c' }, { body: 'body', status: 200 })

    response = Excon.get('http://example.com', query: { 'a' => 'b c' }, mock: true)

    assert_equal 200, response.status
    assert_equal 'body', response.body
  end

  def test_url_with_userinfo_matches
    Excon.stub({ url: 'https://user:pass@foo.bar.com:9999/baz?quux=true' }, { status: 200 })

    response = Excon.new('https://user:pass@foo.bar.com:9999/baz?quux=true', mock: true).get(expects: 200)

    assert_equal 200, response.status
  end
end

# A block stub is called with the request params, plus any Regexp matches in
# params[:captures], and returns the response params.
class MockBlockStubTest < Minitest::Test
  include WithoutProxyEnv
  include MockTestHelpers

  # the headers excon sends by default
  REQUEST_HEADERS = {
    'Accept' => '*/*',
    'Accept-Encoding' => 'deflate, gzip',
    'Host' => '127.0.0.1:9292',
    'User-Agent' => "excon/#{Excon::VERSION}"
  }.freeze

  def stub_echo
    Excon.stub({ body: 'body', method: :get }) do |params|
      { body: params[:body], headers: params[:headers], status: 200 }
    end
  end

  def test_block_receives_regexp_captures
    Excon.stub({ path: %r{/tests/(\S+)} }) do |params|
      { body: params[:captures][:path].first, status: 200 }
    end

    response = connection.request(method: :get, path: '/tests/test')

    assert_equal 'test', response.body
    assert_equal({}, response.headers)
    assert_equal 200, response.status
  end

  def test_block_receives_request_params
    stub_echo

    response = connection.request(body: 'body', method: :get, path: '/content-length/100')

    assert_equal 'body', response.body
    assert_equal REQUEST_HEADERS, response.headers
    assert_equal 200, response.status
  end

  def test_block_response_body_is_yielded_to_response_block
    stub_echo

    assert_equal ['body'], collect_chunks(body: 'body', method: :get, path: '/content-length/100')
  end

  def test_block_response_body_is_empty_with_response_block
    stub_echo

    response = request_with_empty_response_block(body: 'body', method: :get, path: '/content-length/100')

    assert_equal '', response.body
  end
end

class MockStubRegistryTest < Minitest::Test
  include WithoutProxyEnv
  include MockTestHelpers

  def test_stub_for_returns_matching_stub
    Excon.stub({}, {})

    assert_equal [{}, {}], Excon.stub_for({})
  end

  def test_unstub_returns_removed_stub
    Excon.stub({}, {})

    assert_equal [{}, {}], Excon.unstub({})
    assert_raises(Excon::Errors::StubNotFound) { connection.request(method: :get) }
  end

  def test_unstub_matches_regexp_param_by_equality
    request_params = { path: %r{/path} }
    Excon.stub(request_params, {})

    # Excon.stub keeps request_params itself, and stub_for adds :captures to
    # the params it's given (here the same hash), so it shows up in the result
    assert_equal [{ path: %r{/path}, captures: { headers: {} } }, {}], Excon.unstub(request_params)
  end

  def test_unstub_without_matching_stub_returns_nil
    assert_nil Excon.unstub({})
  end

  def test_global_stubs_are_shared_across_threads
    Excon.stub({}, { body: '1' })

    # both threads see the newest stub, added by the other thread
    assert_equal '2', stub_and_request_on_another_thread('2')
    assert_equal '2', connection.request(method: :get).body
  end

  def test_local_stubs_are_per_thread
    with_local_stubs do
      Excon.stub({}, { body: '1' })

      assert_equal '2', stub_and_request_on_another_thread('2')
      # the other thread's stub isn't visible here
      assert_equal '1', connection.request(method: :get).body
    end
  end

  private

  def stub_and_request_on_another_thread(body)
    Thread.new do
      Excon.stub({}, { body: body })
      connection.request(method: :get).body
    end.value
  end

  def with_local_stubs
    original_defaults = Excon.defaults
    Excon.defaults = Excon.defaults.merge(stubs: :local)
    yield
  ensure
    Excon.stubs.clear
    Excon.defaults = original_defaults
  end
end

# allow_unstubbed_requests sends a request that matches no stub to the server.
class MockUnstubbedRequestTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include MockTestHelpers

  test_server :exec, 'good_ipv4.rb'

  def test_allow_unstubbed_requests_sends_request
    Excon.stub({ path: '/echo/request_count' }, { body: 'body' })

    response = Excon.get('http://127.0.0.1:9292/echo/request', mock: true, allow_unstubbed_requests: true)

    assert_equal 200, response.status
    refute_equal 'body', response.body
  end
end
