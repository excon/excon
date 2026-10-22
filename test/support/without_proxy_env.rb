# frozen_string_literal: true

# Clears the proxy environment variables (which Excon.new reads) for each
# test, and restores them after, so a developer's or CI's proxy settings
# don't route requests to the local test servers through a proxy.
#
#   class FooTest < Minitest::Test
#     include WithoutProxyEnv
#   end
module WithoutProxyEnv
  PROXY_ENV_KEYS = %w[http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY].freeze

  def setup
    super
    @saved_proxy_env = PROXY_ENV_KEYS.to_h { |key| [key, ENV.delete(key)] }
  end

  def teardown
    @saved_proxy_env&.each { |key, value| ENV[key] = value }
    super
  end
end
