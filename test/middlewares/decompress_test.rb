# frozen_string_literal: true

require_relative '../test_helper'
require 'stringio'
require 'zlib'

# Decompress (a default middleware) asks for compressed responses by setting
# Accept-Encoding, then decodes a gzip or deflate body and removes that
# encoding from Content-Encoding. It leaves the response alone when the last
# encoding applied is one it doesn't know, or when a :response_block is used.
#
# The server's /echo/content-encoded returns the request body encoded with
# the last of gzip, deflate or deflate-raw it finds in Accept-Encoding (or
# unencoded if none). Content-Encoding-Pre and Content-Encoding-Post request
# headers add an encoding before or after that one, as if the server had
# applied it too. Content-Encoding-Sent reports the Content-Encoding the
# server sent, before the client changed it.
class DecompressTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :exec, 'good_ipv4.rb'

  def content_encoded(**params)
    Excon.post('http://127.0.0.1:9292/echo/content-encoded', body: 'hello world', **params)
  end

  def gunzip(data)
    Zlib::GzipReader.new(StringIO.new(data)).read
  end

  def test_gzip_body_is_decompressed
    response = content_encoded(headers: { 'Accept-Encoding' => 'gzip, deflate;q=0' })

    assert_equal 'gzip', response.headers['Content-Encoding-Sent']
    assert_equal '', response.headers['Content-Encoding']
    assert_equal 'hello world', response.body
  end

  def test_empty_gzip_body_is_left_empty
    # without an Accept-Encoding, Decompress asks for 'deflate, gzip'
    response = content_encoded(body: '')

    assert_equal 'gzip', response.headers['Content-Encoding-Sent']
    assert_equal '', response.body
  end

  def test_deflate_body_is_decompressed
    response = content_encoded(headers: { 'Accept-Encoding' => 'gzip;q=0, deflate' })

    assert_equal 'deflate', response.headers['Content-Encoding-Sent']
    assert_equal '', response.headers['Content-Encoding']
    assert_equal 'hello world', response.body
  end

  def test_raw_deflate_body_is_decompressed
    # the server labels raw deflate (no zlib header) as plain deflate
    response = content_encoded(headers: { 'Accept-Encoding' => 'deflate-raw' })

    assert_equal 'deflate', response.headers['Content-Encoding-Sent']
    assert_equal '', response.headers['Content-Encoding']
    assert_equal 'hello world', response.body
  end

  def test_only_the_last_encoding_is_removed
    response = content_encoded(
      headers: { 'Accept-Encoding' => 'gzip, deflate;q=0', 'Content-Encoding-Pre' => 'other' }
    )

    assert_equal 'other, gzip', response.headers['Content-Encoding-Sent']
    assert_equal 'other', response.headers['Content-Encoding']
    assert_equal 'hello world', response.body
  end

  def test_unknown_last_encoding_is_left_alone
    response = content_encoded(
      headers: { 'Accept-Encoding' => 'gzip, deflate;q=0', 'Content-Encoding-Post' => 'other' }
    )

    assert_equal 'gzip, other', response.headers['Content-Encoding-Sent']
    assert_equal 'gzip, other', response.headers['Content-Encoding']
    # 'other' is a made-up encoding, so the body is only gzipped
    assert_equal 'hello world', gunzip(response.body)
  end

  def test_response_block_gets_the_body_undecompressed
    chunks = []
    response = content_encoded(
      headers: { 'Accept-Encoding' => 'gzip' },
      response_block: ->(chunk, _remaining, _total) { chunks << chunk }
    )

    assert_equal 'gzip', response.headers['Content-Encoding-Sent']
    assert_equal 'gzip', response.headers['Content-Encoding']
    assert_equal 'hello world', gunzip(chunks.join)
  end

  # /echo/request returns the request it received, Marshal-dumped.
  def echoed_request(data)
    Marshal.load(data) # rubocop:disable Security/MarshalLoad -- from our own fixture server
  end

  def test_adds_accept_encoding
    response = Excon.post('http://127.0.0.1:9292/echo/request', body: 'hello world')
    request = echoed_request(response.body)

    assert_equal 'deflate, gzip', request[:headers]['Accept-Encoding']
  end

  def test_does_not_add_accept_encoding_with_a_response_block
    chunks = []
    Excon.post(
      'http://127.0.0.1:9292/echo/request',
      body: 'hello world',
      response_block: ->(chunk, _remaining, _total) { chunks << chunk }
    )
    request = echoed_request(chunks.join)

    assert_nil request[:headers]['Accept-Encoding']
  end
end

class DecompressStubTest < Minitest::Test
  def teardown
    Excon.stubs.clear
    super
  end

  def test_empty_content_encoding_leaves_body_alone
    Excon.stub({ method: :get }, { body: 'body', headers: { 'Content-Encoding' => '' }, status: 200 })

    response = Excon.new('http://example.com', mock: true).request(method: :get)

    assert_equal 'body', response.body
  end
end
