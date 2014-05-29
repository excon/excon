module Excon
  class StandardInstrumentor
    def self.instrument(name, params = {}, &block)
      params = params.dup

      # reduce duplication/noise of output
      params.delete(:connection)
      params.delete(:stack)

      if params.has_key?(:headers) && params[:headers].has_key?('Authorization')
        params[:headers] = params[:headers].dup
        params[:headers]['Authorization'] = REDACTED
      end

      if params.has_key?(:password)
        params[:password] = REDACTED
      end

      $stderr.puts(name)
      indent = 0
      pretty_printer = lambda do |hash|
        indent += 2
        max_key_length = hash.keys.map {|key| key.inspect.length}.max
        hash.keys.sort_by {|key| key.to_s}.each do |key|
          value = hash[key]
          $stderr.write("#{' ' * indent}#{key.inspect.ljust(max_key_length)} => ")
          case value
          when Array
            $stderr.puts("[")
            value.each do |v|
              $stderr.puts("#{' ' * indent}  #{v.inspect}")
            end
            $stderr.write("#{' ' * indent}]")
          when Hash
            $stderr.puts("{")
            pretty_printer.call(value)
            $stderr.write("#{' ' * indent}}")
          else
            $stderr.write("#{value.inspect}")
          end
          $stderr.puts
        end
        indent -= 2
      end
      pretty_printer.call(params)

      if block_given?
        yield
      end
    end
  end
end
