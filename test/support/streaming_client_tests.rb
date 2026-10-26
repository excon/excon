# frozen_string_literal: true

# Reading a response that the server sends in pieces, run against
# tests/rackups/streaming.ru or tests/servers/ssl_streaming.rb.
#
#   class FooTest < Minitest::Test
#     include TestServer
#     include StreamingClientTests
#     test_server :puma, 'streaming.ru'
#
#     def url = 'http://127.0.0.1:9292'
#   end
#
# Both servers send PIECES, sleeping DELAY before each one. /streamed/simple
# sends no Content-Length and closes the connection after the last piece;
# /streamed/fixed_length sends a Content-Length.
module StreamingClientTests
  PIECES = %w[Hello streamy world].freeze
  DELAY = 0.1

  %w[simple fixed_length].each do |path|
    define_method("test_#{path}_response_body_has_every_piece") do
      start = Time.now
      response = connection.request(method: :get, path: "/streamed/#{path}")
      elapsed = Time.now - start

      assert_equal PIECES.join, response.body
      # the body is only returned after the server's last piece
      assert_operator elapsed, :>, DELAY * PIECES.length
    end

    define_method("test_#{path}_response_block_gets_each_piece_as_it_arrives") do
      start = Time.now
      chunks, times = stream("/streamed/#{path}")
      elapsed = Time.now - start

      assert_equal PIECES, chunks
      assert_operator elapsed, :>, DELAY * PIECES.length
      # Connection setup (e.g. a slow TLS handshake on JRuby) delays the first
      # piece by an unknown amount, so it only gets a lower bound.
      assert_operator times.first - start, :>=, DELAY
      # later pieces arrive about DELAY apart, measured from the first
      times.each_with_index.drop(1).each do |time, index|
        assert_in_delta index * DELAY, time - times.first, DELAY / 2
      end
    end
  end

  private

  def connection
    Excon.new(url, ssl_verify_peer: false)
  end

  # Returns the chunks passed to a response_block and when each arrived.
  def stream(path)
    chunks = []
    times = []
    response_block = lambda do |chunk, _remaining_length, _total_length|
      chunks << chunk
      times << Time.now
    end
    connection.request(method: :get, path: path, response_block: response_block)
    [chunks, times]
  end
end
