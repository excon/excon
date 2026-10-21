# frozen_string_literal: true

require_relative 'test_helper'

class ProxyEnvironmentTest < Minitest::Test
  PROXY_ENV_KEYS = %w[http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY].freeze

  def test_no_proxy_escapes_hostname_regex_metacharacters
    with_proxy_environment('http_proxy' => 'http://proxy.example:8080', 'no_proxy' => 'sub.example.com') do
      assert_nil Excon.new('http://sub.example.com').data[:proxy]
      assert Excon.new('http://subxexample.com').data[:proxy]
    end
  end

  def test_no_proxy_asterisk_matches_all_hosts
    with_proxy_environment('http_proxy' => 'http://proxy.example:8080', 'no_proxy' => '*') do
      assert_nil Excon.new('http://example.com').data[:proxy]
    end
  end

  private

  def with_proxy_environment(values)
    original = PROXY_ENV_KEYS.to_h { |key| [key, ENV[key]] }
    PROXY_ENV_KEYS.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    PROXY_ENV_KEYS.each { |key| ENV.delete(key) }
    original&.each { |key, value| ENV[key] = value if value }
  end
end
