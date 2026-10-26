# frozen_string_literal: true

require_relative 'in_process_server'

# Runs an in-process test server (see in_process_server.rb) around each test
# class that declares one.
#
#   class FooTest < Minitest::Test
#     include TestServer
#     test_server :webrick, 'basic.ru'
#
#     def test_get
#       assert_equal 200, Excon.get('http://127.0.0.1:9292/').status
#     end
#   end
#
# The server starts before the class's first test and stops after its last,
# so classes that bind the same port don't collide.
module TestServer
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    attr_reader :server

    # kind: :webrick or :puma (file is in test/fixtures/rackups), or :exec
    # (file is in test/fixtures/servers)
    def test_server(kind, file, bind: nil)
      @test_server_args = [kind, file, { bind: bind }]
    end

    # Minitest (>= 6) runs each class's tests via run_suite.
    def run_suite(reporter, options = {})
      return super if @test_server_args.nil? || filter_runnable_methods(options).empty?

      kind, file, server_options = @test_server_args
      @server = InProcessServer.new(kind, file, **server_options).start
      begin
        super
      ensure
        @server.stop
        @server = nil
      end
    end
  end

  def server
    self.class.server
  end
end
