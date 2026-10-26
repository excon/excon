# frozen_string_literal: true

require_relative 'check'

module BasicClientTests
  # Sending request bodies: /body-sink returns the size of the body it got,
  # /echo returns the body itself.
  module RequestBodies
    extend Check

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

    %i[post put].each do |http_method|
      check "#{http_method}_sends_a_file_body" do |options|
        response = File.open(data_path('xs')) do |file|
          echo(http_method, options, body: file)
        end

        assert_equal "#{'x' * 100}\n", response.body
      end

      check "#{http_method}_does_not_change_the_body_encoding" do |options|
        body = +'¥£€'
        echo(http_method, options, body: body)

        assert_equal Encoding::UTF_8, body.encoding
      end

      check "#{http_method}_sends_a_string_body" do |options|
        assert_equal 'x' * 100, echo(http_method, options, body: 'x' * 100).body
      end

      check "#{http_method}_sends_a_body_from_request_block" do |options|
        data = Array.new(100, 'x')
        request_block = -> { data.shift.to_s }

        assert_equal 'x' * 100, echo(http_method, options, request_block: request_block).body
      end

      # A UTF-8 header alongside a binary body must not raise an encoding
      # error or garble the body when they're joined into one request.
      check "#{http_method}_sends_a_multibyte_body_and_header" do |options|
        body = ("\xC3\xBC" * 100).b
        headers = { 'Custom' => body.dup.force_encoding('UTF-8') }

        assert_equal body, echo(http_method, options, headers: headers, body: body).body
      end
    end
  end
end
