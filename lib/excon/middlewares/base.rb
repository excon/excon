module Excon
  module Middleware
    class Base
      def initialize(stack)
        @stack = stack
      end

      def before(datum)
        # do stuff
        @stack.before(datum)
      end

      def after(datum)
        @stack.after(datum)
        # do stuff
      end
    end
  end
end
