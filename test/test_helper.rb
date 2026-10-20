# frozen_string_literal: true

TEST_SUITE_DEFAULTS = {
  connect_timeout: 5,
  read_timeout: 5,
  write_timeout: 5
}.freeze

require 'excon'
require 'minitest/autorun'

# Shared with the rspec suite until it has been migrated.
require_relative '../spec/helpers/file_path_helpers'
require_relative '../spec/helpers/warning_helpers'
require_relative '../spec/support/excon/test/server'

require_relative 'support/test_server'

Excon.set_raise_on_warnings!(true)
