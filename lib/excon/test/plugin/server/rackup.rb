module Excon
  module Test
    module Plugin
      module Server
        module Rackup
          def start(app_str = app, bind_str = bind)
            open_process('rackup', '--host', bind, app)
            line = ''
            until line =~ /HTTPServer#start:|Use Ctrl-C to stop/
              line = RUBY_PLATFORM == 'java' ? read.gets : error.gets
              fatal_time = elapsed_time > timeout
              raise 'rackup server has taken too long to start' if fatal_time
            end
            true
          end
        end
      end
    end
  end
end
