# frozen_string_literal: true

require_relative 'test_helper'

# How Excon reads a response: its body, framed by chunked transfer-encoding, a
# Content-Length or the connection closing; its headers, including trailers,
# cookies and continuation lines; and its status line.
#
# The server's /chunked/simple, /content-length/simple and /unknown/simple
# each return 'hello world', framed as their names say. /chunked/simple sends
# it as the chunks 'hello ' and 'world'. A :response_block is called with
# (chunk, remaining_bytes, total_bytes); the byte counts are nil unless the
# response has a Content-Length.
module ResponseTestHelpers
  private

  def get(path, **)
    Excon.get("http://127.0.0.1:9292#{path}", **)
  end

  # Returns the arguments of each call to the :response_block.
  def capture_response_block(path, **)
    calls = []
    get(path, response_block: ->(*args) { calls << args }, **)
    calls
  end

  # A response whose status isn't expected is read in full, without calling
  # the :response_block, so the error carries the body.
  def unexpected_status_body(path, **)
    error = assert_raises(Excon::Error::HTTPStatus) do
      get(path, response_block: proc { flunk 'response_block was called' }, expects: 500, **)
    end
    error.response[:body]
  end
end

class ChunkedResponseTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ResponseTestHelpers

  test_server :exec, 'good_ipv4.rb'

  def test_chunked_body
    assert_equal 'hello world', get('/chunked/simple').body
  end

  def test_chunked_response_block_gets_each_chunk_as_sent
    # :chunk_size doesn't apply; chunks are passed on as the server sent them
    chunks = capture_response_block('/chunked/simple', chunk_size: 5)

    assert_equal 2, chunks.length
    assert_equal ['hello ', nil, nil], chunks[0]
    assert_equal ['world', nil, nil], chunks[1]
  end

  def test_chunked_response_block_leaves_body_empty
    assert_equal '', get('/chunked/simple', response_block: ->(_, _, _) {}).body
  end

  def test_chunked_response_block_with_expected_status
    chunks = capture_response_block('/chunked/simple', expects: 200)

    assert_equal 2, chunks.length
    assert_equal ['hello ', nil, nil], chunks[0]
    assert_equal ['world', nil, nil], chunks[1]
  end

  def test_chunked_unexpected_status_reads_body_without_response_block
    assert_equal 'hello world', unexpected_status_body('/chunked/simple')
  end

  def test_chunked_trailers_are_merged_into_headers
    # 'one, two' comes in the headers; 'three, four, five, six' in a trailer
    # with a continuation line
    assert_equal 'one, two, three, four, five, six', get('/chunked/trailers').headers['Test-Header']
  end

  def test_chunked_is_removed_from_transfer_encoding
    assert_nil get('/chunked/simple').headers['Transfer-Encoding']
  end
end

class ContentLengthResponseTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ResponseTestHelpers

  test_server :exec, 'good_ipv4.rb'

  def test_content_length_body
    assert_equal 'hello world', get('/content-length/simple').body
  end

  def test_content_length_response_block_gets_chunk_size_pieces
    chunks = capture_response_block('/content-length/simple', chunk_size: 5)

    assert_equal 3, chunks.length
    assert_equal ['hello', 6, 11], chunks[0]
    assert_equal [' worl', 1, 11], chunks[1]
    assert_equal ['d', 0, 11], chunks[2]
  end

  def test_content_length_response_block_leaves_body_empty
    assert_equal '', get('/content-length/simple', response_block: ->(_, _, _) {}).body
  end

  def test_content_length_response_block_with_expected_status
    chunks = capture_response_block('/content-length/simple', chunk_size: 5, expects: 200)

    assert_equal 3, chunks.length
    assert_equal ['hello', 6, 11], chunks[0]
    assert_equal [' worl', 1, 11], chunks[1]
    assert_equal ['d', 0, 11], chunks[2]
  end

  def test_content_length_unexpected_status_reads_body_without_response_block
    assert_equal 'hello world', unexpected_status_body('/content-length/simple', chunk_size: 5)
  end
end

# The body ends when the server closes the connection.
class UnknownLengthResponseTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ResponseTestHelpers

  test_server :exec, 'good_ipv4.rb'

  def test_unknown_length_body
    assert_equal 'hello world', get('/unknown/simple').body
  end

  def test_unknown_length_response_block_gets_chunk_size_pieces
    chunks = capture_response_block('/unknown/simple', chunk_size: 5)

    assert_equal 3, chunks.length
    assert_equal ['hello', nil, nil], chunks[0]
    assert_equal [' worl', nil, nil], chunks[1]
    assert_equal ['d', nil, nil], chunks[2]
  end

  def test_unknown_length_response_block_leaves_body_empty
    assert_equal '', get('/unknown/simple', response_block: ->(_, _, _) {}).body
  end

  def test_unknown_length_response_block_with_expected_status
    chunks = capture_response_block('/unknown/simple', chunk_size: 5, expects: 200)

    assert_equal 3, chunks.length
    assert_equal ['hello', nil, nil], chunks[0]
    assert_equal [' worl', nil, nil], chunks[1]
    assert_equal ['d', nil, nil], chunks[2]
  end

  def test_unknown_length_unexpected_status_reads_body_without_response_block
    assert_equal 'hello world', unexpected_status_body('/unknown/simple', chunk_size: 5)
  end
end

# Response headers and the status line.
class ResponseHeaderTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv
  include ResponseTestHelpers

  test_server :exec, 'good_ipv4.rb'

  def test_cookies_are_parsed_into_an_array
    # one entry per Set-Cookie header, not split on commas
    assert_equal ['one, two', 'three, four'], get('/unknown/cookies')[:cookies]
  end

  def test_header_continuation_is_joined
    # sent as 'Test-Header: one, two', then 'Test-Header: three, four,'
    # continued on the next line by '  five, six'
    assert_equal 'one, two, three, four, five, six', get('/unknown/header_continuation').headers['Test-Header']
  end

  def test_malformed_header_raises
    # a header line without ':'
    assert_raises(Excon::Error::Socket) { get('/bad/malformed_header') }
  end

  def test_malformed_header_continuation_raises
    # a continuation line with no header before it
    assert_raises(Excon::Error::Socket) { get('/bad/malformed_header_continuation') }
  end

  def test_status_code
    assert_equal 404, get('/not-found').status
  end

  def test_reason_phrase
    assert_equal 'Not Found', get('/not-found').reason_phrase
  end
end
