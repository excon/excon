# frozen_string_literal: true

require_relative 'check'

module BasicClientTests
  # What GET /content-length/100 returns, and the ways of reading it.
  module Responses
    extend Check

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

    check 'get_returns_the_custom_header' do |options|
      assert_equal 'Foo: bar', get_content(options).headers['Custom']
    end

    check 'get_returns_the_body' do |options|
      assert_equal 'x' * 100, get_content(options).body
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
  end
end
