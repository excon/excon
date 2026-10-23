# frozen_string_literal: true

require 'tempfile'

require_relative 'test_helper'

# Excon::Socket looks hostnames up with the :resolv_resolver connection
# option if given, and otherwise with a resolver from :resolver_factory
# (Excon::ResolverFactory by default). These tests resolve the made-up host
# excon.test to 127.0.0.1 through a hosts file of their own, so a request
# only reaches the test server if it used the expected resolver, and no real
# DNS is needed.
class ResolvResolverTest < Minitest::Test
  include TestServer
  include WithoutProxyEnv

  test_server :webrick, 'basic.ru'

  URL = 'http://excon.test:9292'

  def setup
    super
    @hosts_file = Tempfile.new('hosts')
    @hosts_file.write("127.0.0.1 excon.test\n")
    @hosts_file.close
    count_default_factory_calls
    use_custom_factory
  end

  # Counts calls to the default factory, still calling through to it.
  def count_default_factory_calls
    calls = @default_factory_calls = []
    @original_create_resolver = original = Excon::ResolverFactory.method(:create_resolver)
    Excon::ResolverFactory.define_singleton_method(:create_resolver) do
      calls << :create_resolver
      original.call
    end
  end

  # Sets a factory whose resolvers know excon.test as the global default.
  def use_custom_factory
    calls = @custom_factory_calls = []
    hosts_file = @hosts_file.path
    custom_factory = Class.new
    custom_factory.define_singleton_method(:create_resolver) do
      calls << :create_resolver
      Resolv.new([Resolv::Hosts.new(hosts_file)])
    end
    @original_defaults = Excon.defaults
    Excon.defaults = Excon.defaults.merge(resolver_factory: custom_factory).freeze
  end

  def teardown
    Excon.defaults = @original_defaults
    Excon::ResolverFactory.define_singleton_method(:create_resolver, @original_create_resolver)
    @hosts_file.unlink
    super
  end

  def hosts_resolver
    Resolv.new([Resolv::Hosts.new(@hosts_file.path)])
  end

  def test_resolv_resolver_is_used_for_lookup
    # Back to the default factory, whose resolvers don't know excon.test.
    Excon.defaults = @original_defaults
    connection = Excon.new(URL, resolv_resolver: hosts_resolver)

    response = connection.get(path: '/')
    assert_equal 200, response.status
    assert_equal '127.0.0.1', response.remote_ip
  end

  def test_resolv_resolver_skips_custom_resolver_factory
    connection = Excon.new(URL, resolv_resolver: hosts_resolver)

    connection.get(path: '/')
    assert_empty @custom_factory_calls
  end

  def test_resolv_resolver_skips_default_resolver_factory
    connection = Excon.new(URL, resolv_resolver: hosts_resolver)

    connection.get(path: '/')
    assert_empty @default_factory_calls
  end

  def test_unreachable_dns_server_raises_socket_error
    # Nothing answers DNS on 127.0.0.1, so the lookup fails.
    dns_resolver = Resolv::DNS.new(nameserver: ['127.0.0.1'])
    dns_resolver.timeouts = 1
    connection = Excon.new(URL, resolv_resolver: Resolv.new([dns_resolver]))

    error = assert_raises(Excon::Error::Socket) { connection.get(path: '/') }
    assert_kind_of Resolv::ResolvError, error.socket_error
    assert_match(/no address for excon.test/, error.message)
  end

  def test_without_resolv_resolver_uses_configured_resolver_factory
    connection = Excon.new(URL)

    response = connection.get(path: '/')
    assert_equal 200, response.status
    assert_equal [:create_resolver], @custom_factory_calls
  end

  def test_without_resolv_resolver_skips_default_resolver_factory
    connection = Excon.new(URL)

    connection.get(path: '/')
    assert_empty @default_factory_calls
  end
end
