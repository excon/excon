describe Excon::Connection do
  include_context('stubs')
  describe 'validating parameters' do
    class FooMiddleware < Excon::Middleware::Base
      def self.valid_parameter_keys
        [:foo]
      end
    end

    let(:foo_stack) do
      Excon.defaults[:middlewares] + [FooMiddleware]
    end

    def expect_parameter_warning(validation, key)
      expect { yield }.to raise_error(Excon::Error::Warning, "Invalid Excon #{validation} keys: #{key.inspect}")
    end

    context 'with default middleware' do
      it 'Connection.new warns on invalid parameter keys' do
        expect_parameter_warning('connection', :foo) do
          Excon.new('http://foo', :foo => :bar)
        end
      end

      it 'Connection#request warns on invalid parameter keys' do
        conn = Excon.new('http://foo')
        expect_parameter_warning('request', :foo) do
          conn.request(:foo => :bar)
        end
      end
    end

    context 'with custom middleware at instantiation' do
      it 'Connection.new accepts parameters that are valid for the provided middleware' do
        Excon.new('http://foo', :foo => :bar, :middlewares => foo_stack)
      end

      it 'Connection.new warns on parameters that are not valid for the provided middleware' do
        expect_parameter_warning('connection', :bar) do
          Excon.new('http://foo', :bar => :baz, :middlewares => foo_stack)
        end
      end

      it 'Connection#request accepts parameters that are valid for the provided middleware' do
        Excon.stub({}, {})
        conn = Excon.new('http://foo', :middlewares => foo_stack)
        conn.request(:foo => :bar)
      end

      it 'Connection#request warns on parameters that are not valid for the provided middleware' do
        conn = Excon.new('http://foo', :middlewares => foo_stack)
        expect_parameter_warning('request', :bar) do
          conn.request(:bar => :baz)
        end
      end
    end

    context 'with custom middleware at request time' do
      it 'Connection#request accepts parameters that are valid for the provided middleware' do
        Excon.stub({}, {})
        conn = Excon.new('http://foo')
        conn.request(:foo => :bar, :middlewares => foo_stack)
      end

      it 'Connection#request warns on parameters that are not valid for the request middleware' do
        conn = Excon.new('http://foo')
        expect_parameter_warning('request', :bar) do
          conn.request(:bar => :baz, :middlewares => foo_stack)
        end
      end

      it 'Connection#request warns on parameters from instantiation that are not valid for the request middleware' do
        conn = Excon.new('http://foo', :foo => :bar, :middlewares => foo_stack)
        expect_parameter_warning('connection', :foo) do
          conn.request(:middlewares => Excon.defaults[:middlewares])
        end
      end
    end
  end
end