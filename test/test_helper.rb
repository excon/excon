# frozen_string_literal: true

TEST_SUITE_DEFAULTS = {
  connect_timeout: 5,
  read_timeout: 5,
  write_timeout: 5
}.freeze

require 'excon'
require 'minitest/autorun'

require_relative 'support/file_path_helpers'
require_relative 'support/test_server'
require_relative 'support/warning_helpers'
require_relative 'support/without_proxy_env'

Excon.set_raise_on_warnings!(true)
