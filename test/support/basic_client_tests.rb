# frozen_string_literal: true

require_relative 'basic_client_tests/check'
require_relative 'basic_client_tests/method_and_path_defaults'
require_relative 'basic_client_tests/request_bodies'
require_relative 'basic_client_tests/responses'
require_relative 'basic_client_tests/server_details'

# Requests every client configuration should handle, run against
# test/fixtures/rackups/basic.ru. Each check becomes one test per combination
# of :nonblock and :persistent.
#
#   class FooTest < Minitest::Test
#     include TestServer
#     include BasicClientTests
#     test_server :webrick, 'basic.ru'
#
#     # optional; these are the defaults
#     def url = 'http://127.0.0.1:9292'
#     def client_options = {}
#   end
#
# basic.ru's /content-length/N returns N 'x's with a 'Custom: Foo: bar'
# header. The checks are grouped by what they cover, in basic_client_tests/;
# a class whose server can't run a group includes the others instead.
module BasicClientTests
  include Helpers
  include MethodAndPathDefaults
  include Responses
  include RequestBodies
  include ServerDetails
end
