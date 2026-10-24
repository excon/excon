# frozen_string_literal: true

require 'time'

# Requests every client configuration should handle, run against
# tests/rackups/basic.ru. Each check becomes one test per combination of
# :nonblock and :persistent.
#
#   class FooTest < Minitest::Test
#     include TestServer
#     include BasicClientTests
#     test_server :webrick, 'basic.ru'
#
#     # optional; these are the defaults
#     def url = 'http://127.0.0.1:9292'
#     def client_options = {}
#   end
#
# basic.ru's /content-length/N returns N 'x's with a 'Custom: Foo: bar'
# header, /body-sink returns the size of the request body, and /echo returns
# the request body.
module BasicClientTests # rubocop:disable Metrics/ModuleLength
  OPTION_COMBINATIONS = [true, false].product([true, false]).map do |nonblock, persistent|
    { nonblock: nonblock, persistent: persistent }
  end.freeze

  # Defines test_<name>_with_nonblock_<x>_persistent_<y> for each
  # combination; the block gets the options to pass to connection.
  def self.check(name, &block)
    OPTION_COMBINATIONS.each do |options|
      define_method("test_#{name}_with_nonblock_#{options[:nonblock]}_persistent_#{options[:persistent]}") do
        instance_exec(options, &block)
      end
    end
  end

  def url
    'http://127.0.0.1:9292'
  end

  def client_options
    {}
  end

  check 'get_returns_a_response_with_status_200' do |options|
    response = get_content(options)

    assert_instance_of Excon::Response, response
    assert_equal 200, response.status
    assert_equal 200, response[:status]
  end

  check 'get_returns_content_headers' do |options|
    response = get_content(options)

    assert_equal '100', response.headers['Content-Length']
    assert_equal 'text/html;charset=utf-8', response.headers['Content-Type']
  end

  check 'get_returns_a_date_header' do |options|
    connection = connection(options)
    skip 'until puma responds with a date header' if RUBY_PLATFORM == 'java' && unix?(connection)

    response = connection.request(method: :get, path: '/content-length/100')

    assert_instance_of Time, Time.parse(response.headers['Date'])
  end

  check 'get_returns_a_webrick_server_header' do |options|
    connection = connection(options)
    skip 'until unix_socket response has server header' if unix?(connection)

    response = connection.request(method: :get, path: '/content-length/100')

    assert_match(/^WEBrick/, response.headers['Server'])
  end

  check 'get_returns_the_custom_header' do |options|
    assert_equal 'Foo: bar', get_content(options).headers['Custom']
  end

  check 'get_returns_the_remote_ip' do |options|
    connection = connection(options)
    skip 'unix sockets have no remote ip' if unix?(connection)

    response = connection.request(method: :get, path: '/content-length/100')

    assert_equal '127.0.0.1', response.remote_ip
  end

  check 'get_with_tcp_nodelay_returns_status_200' do |options|
    response = get_content(options.merge(tcp_nodelay: true))

    assert_equal 200, response.status
  end

  check 'deprecated_request_block_yields_chunk_and_lengths' do |options|
    connection = connection(options)
    data = nil
    silence_warnings do
      connection.request(method: :get, path: '/content-length/100') do |chunk, remaining_length, total_length|
        data = [chunk, remaining_length, total_length]
      end
    end

    assert_equal ['x' * 100, 0, 100], data
  end

  check 'response_block_yields_chunk_and_lengths' do |options|
    data = nil
    response_block = lambda do |chunk, remaining_length, total_length|
      data = [chunk, remaining_length, total_length]
    end
    connection(options).request(method: :get, path: '/content-length/100', response_block: response_block)

    assert_equal ['x' * 100, 0, 100], data
  end

  check 'post_sends_a_large_body' do |options|
    response = connection(options).request(
      method: :post, path: '/body-sink',
      headers: { 'Content-Type' => 'text/plain' }, body: 'x' * 5_000_000
    )

    assert_instance_of Excon::Response, response
    assert_equal '5000000', response.body
  end

  check 'post_sends_an_empty_body' do |options|
    response = connection(options).request(
      method: :post, path: '/body-sink',
      headers: { 'Content-Type' => 'text/plain' }, body: ''
    )

    assert_instance_of Excon::Response, response
    assert_equal '0', response.body
  end

  check 'post_sends_a_file_body' do |options|
    response = File.open(data_path('xs')) do |file|
      post_echo(options, body: file)
    end

    assert_equal "#{'x' * 100}\n", response.body
  end

  check 'post_does_not_change_the_body_encoding' do |options|
    body = +'¥£€'
    post_echo(options, body: body)

    assert_equal Encoding::UTF_8, body.encoding
  end

  check 'post_sends_a_string_body' do |options|
    assert_equal 'x' * 100, post_echo(options, body: 'x' * 100).body
  end

  check 'post_sends_a_body_from_request_block' do |options|
    data = Array.new(100, 'x')
    request_block = -> { data.shift.to_s }

    assert_equal 'x' * 100, post_echo(options, request_block: request_block).body
  end

  # A UTF-8 header alongside a binary body must not raise an encoding error
  # or garble the body when they're joined into one request.
  check 'post_sends_a_multibyte_body_and_header' do |options|
    body = ("\xC3\xBC" * 100).b
    headers = { 'Custom' => body.dup.force_encoding('UTF-8') }

    assert_equal body, post_echo(options, headers: headers, body: body).body
  end

  private

  def connection(options)
    Excon.new(url, client_options.merge(ssl_verify_peer: false, **options))
  end

  def unix?(connection)
    connection.data[:scheme] == Excon::UNIX
  end

  def get_content(options)
    connection(options).request(method: :get, path: '/content-length/100')
  end

  def post_echo(options, headers: {}, **params)
    connection(options).request(
      method: :post, path: '/echo',
      headers: { 'Content-Type' => 'text/plain' }.merge(headers), **params
    )
  end
end
