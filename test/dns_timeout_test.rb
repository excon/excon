# frozen_string_literal: true

require_relative 'test_helper'

# The deprecated :dns_timeouts option makes Excon::Socket build its own
# Resolv::DNS and set its timeouts. These tests stub Resolv::DNS.new to return
# a resolver pointed at a nameserver on 127.0.0.1 that isn't there, so no real
# DNS is needed: each lookup waits out the timeout and fails.
class DnsTimeoutTest < Minitest::Test
  def setup
    @dns_resolver = Resolv::DNS.new(nameserver: ['127.0.0.1'])
    resolver = @dns_resolver
    Resolv::DNS.define_singleton_method(:new) { |*| resolver }
  end

  def teardown
    Resolv::DNS.singleton_class.send(:remove_method, :new)
  end

  def test_warns_that_dns_timeouts_is_deprecated
    connection = Excon.new('http://example.com', dns_timeouts: 1)

    error = assert_raises(Excon::Error::Socket) { connection.request }
    assert_kind_of Excon::Error::Warning, error.socket_error
    assert_match(/dns_timeouts is deprecated/, error.message)
  end

  def test_passes_dns_timeouts_to_resolver
    connection = Excon.new('http://example.com', dns_timeouts: 1)

    silence_warnings do
      assert_raises(Excon::Error::Socket) { connection.request }
    end
    timeouts = @dns_resolver.instance_variable_get(:@config).instance_variable_get(:@timeouts)
    assert_equal [1], timeouts
  end

  def test_unreachable_dns_server_raises_socket_error
    connection = Excon.new('http://example.com', dns_timeouts: 1)

    error = silence_warnings do
      assert_raises(Excon::Error::Socket) { connection.request }
    end
    # The lookup itself failed, rather than the deprecation warning.
    assert_kind_of Resolv::ResolvError, error.socket_error
    assert_match(/no address for example.com/, error.message)
  end
end
