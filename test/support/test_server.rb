# frozen_string_literal: true

# Runs an Excon::Test::Server around each test class that declares one.
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

    # plugin: :webrick, :puma or :exec
    # file: a rackup (webrick, puma) or script (exec), relative to tests/
    def test_server(plugin, file, bind: nil)
      @test_server_args = { plugin => send(:"#{plugin}_path", file) }
      @test_server_args[:bind] = bind if bind
    end

    # Minitest (>= 6) runs each class's tests via run_suite.
    def run_suite(reporter, options = {})
      return super if @test_server_args.nil? || filter_runnable_methods(options).empty?

      @server = Excon::Test::Server.new(@test_server_args)
      @server.start
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
