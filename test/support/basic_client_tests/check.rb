# frozen_string_literal: true

module BasicClientTests
  # Extended by each group of checks to define them.
  module Check
    OPTION_COMBINATIONS = [true, false].product([true, false]).map do |nonblock, persistent|
      { nonblock: nonblock, persistent: persistent }
    end.freeze

    # Defines test_<name>_with_nonblock_<x>_persistent_<y> for each
    # combination; the block gets the options to pass to connection.
    def check(name, &block)
      OPTION_COMBINATIONS.each do |options|
        define_method("test_#{name}_with_nonblock_#{options[:nonblock]}_persistent_#{options[:persistent]}") do
          instance_exec(options, &block)
        end
      end
    end
  end

  # Configuration (overridden by the including class) and request helpers
  # shared by the checks.
  module Helpers
    def url
      'http://127.0.0.1:9292'
    end

    def client_options
      {}
    end

    # Closes the test's connections, so persistent ones don't linger until
    # the server stops (which logs an SSL error for each).
    def teardown
      @connections&.each(&:reset)
      super
    end

    private

    def connection(options)
      connection = Excon.new(url, client_options.merge(ssl_verify_peer: false, **options))
      (@connections ||= []) << connection
      connection
    end

    def get_content(options)
      connection(options).request(method: :get, path: '/content-length/100')
    end

    def echo(http_method, options, headers: {}, **params)
      connection(options).request(
        method: http_method, path: '/echo',
        headers: { 'Content-Type' => 'text/plain' }.merge(headers), **params
      )
    end
  end
end
