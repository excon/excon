module Excon
  class StandardInstrumentor
    def self.instrument(name, params = {}, &block)
      $stderr.puts("#{name}  #{params}")
      if block_given?
        yield
      end
    end
  end
end
