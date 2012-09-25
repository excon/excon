module Excon
  class StandardInstrumentor
    def self.instrument(name, params = {}, &block)
      if params.has_key?(:headers) && params[:headers].has_key?('Authorization')
        params = params.dup
        params[:headers] = params[:headers].dup
        params[:headers]['Authorization'] = REDACTED
      end
      $stderr.puts("#{name}  #{params}")
      if block_given?
        yield
      end
    end
  end
end
