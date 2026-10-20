require 'open3'
require 'excon'
require_relative 'plugin/server/webrick'
require_relative 'plugin/server/puma'
require_relative 'plugin/server/exec'


module Excon
  module Test
    class Server
      attr_accessor :app, :server, :bind, :pid, :read, :write, :error, :started_at, :timeout

      # Methods that must be implemented by a plugin
      INSTANCE_REQUIRES = [:start]

      def initialize(args)
        # TODO: Validate these args
        @server = args.keys.first
        @app = args[server]
        args[:bind] ||= 'tcp://127.0.0.1:9292'
        @bind = URI.parse(args[:bind])
        @is_unix_socket = (@bind.scheme == 'unix')
        @bind.host = @bind.host.gsub(/[\[\]]/, '') unless @is_unix_socket
        if args[:timeout]
          @timeout = args[:timeout]
        else
          @timeout = 20
        end
        name = @server.to_s.split('_').collect(&:capitalize).join
        plug = nested_const_get("Excon::Test::Plugin::Server::#{name}")
        self.extend plug
        check_implementation(plug)
      end

      def open_process(*args)
        @write, @read, @error, @wait_thr = Open3.popen3(*args)
        @pid = @wait_thr.pid
        @started_at = Time.now
      end

      def elapsed_time
        Time.now - started_at
      end

      def stop
        begin
          Process.kill('KILL', pid)
        rescue Errno::ESRCH
          # already exited and reaped by the wait thread
        end
        @wait_thr.join

        if @is_unix_socket
          socket = @bind.path
          File.delete(socket) if File.exist?(socket)
        end

        # TODO: Ensure process is really dead
        dump_errors
        true
      end
      def dump_errors
        lines = error.read.split($/)
        while (line = lines.shift)
          case line
            when /(ERROR|Error)/
              unless line.match?(/(null cert chain|did not return a certificate|SSL_read:: internal error)/)
                in_err = true
                puts
              end
            when /^(127|localhost)/
              in_err = false
            end
          puts line if in_err
        end
      end

      private

      def nested_const_get(namespace)
        namespace.split('::').inject(Object) do |mod, klass|
          mod.const_get(klass)
        end
      end

      def check_implementation(plug)
        INSTANCE_REQUIRES.each do |m|
          unless self.respond_to? m
            raise "FATAL: #{plug} does not implement ##{m}"
          end
        end
      end
    end
  end
end
