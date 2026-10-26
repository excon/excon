# frozen_string_literal: true

require_relative 'check'

module BasicClientTests
  # A request without :method or :path is a GET of /, which basic.ru answers
  # with 'GET /'.
  module MethodAndPathDefaults
    extend Check

    check 'request_with_only_a_path_defaults_to_get' do |options|
      assert_equal 'GET /', connection(options).request(path: '/').body
    end

    check 'request_with_only_a_method_defaults_to_the_root_path' do |options|
      assert_equal 'GET /', connection(options).request(method: :get).body
    end

    check 'request_with_only_headers_defaults_to_get_of_the_root_path' do |options|
      assert_equal 'GET /', connection(options).request(headers: { 'host' => '127.0.0.1' }).body
    end

    check 'request_with_method_and_path_gets_the_path' do |options|
      assert_equal 'GET /', connection(options).request(method: :get, path: '/').body
    end
  end
end
