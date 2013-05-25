$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'forwardable'
require 'openssl'
require 'rbconfig'
require 'socket'
require 'timeout'
require 'uri'

# Define defaults first so they will be available to other files
module Excon
  class << self

    # @return [Hash] defaults for Excon connections
    def defaults
      @defaults ||= {
        :chunk_size         => CHUNK_SIZE || DEFAULT_CHUNK_SIZE,
        :connect_timeout    => 60,
        :debug_request      => false,
        :debug_response     => false,
        :headers            => {},
        :idempotent         => false,
        :instrumentor_name  => 'excon',
        :middlewares        => [
          Excon::Middleware::Expects,
          Excon::Middleware::Idempotent,
          Excon::Middleware::Instrumentor,
          Excon::Middleware::Mock
        ],
        :mock               => false,
        :nonblock           => DEFAULT_NONBLOCK,
        :omit_default_port  => false,
        :read_timeout       => 60,
        :retry_limit        => DEFAULT_RETRY_LIMIT,
        :ssl_ca_file        => DEFAULT_CA_FILE,
        :ssl_verify_peer    => RbConfig::CONFIG['host_os'] !~ /mswin|win32|dos|cygwin|mingw/i,
        :tcp_nodelay        => false,
        :uri_parser         => URI,
        :write_timeout      => 60
      }
    end

    # Change defaults for Excon connections
    # @return [Hash] defaults for Excon connections
    def defaults=(new_defaults)
      @defaults = new_defaults
    end

  end
end

require 'excon/constants'
require 'excon/connection'
require 'excon/errors'
require 'excon/middlewares/base'
require 'excon/middlewares/expects'
require 'excon/middlewares/idempotent'
require 'excon/middlewares/instrumentor'
require 'excon/middlewares/mock'
require 'excon/response'
require 'excon/socket'
require 'excon/ssl_socket'
require 'excon/standard_instrumentor'

module Excon
  class << self

    def display_warning(warning)
      # Ruby convention mandates complete silence when VERBOSE == nil
      $stderr.puts(warning) if !ENV['VERBOSE'].nil?
    end

    # Status of mocking
    def mock
      display_warning("Excon#mock is deprecated, pass Excon.defaults[:mock] instead (#{caller.first}")
      self.defaults[:mock]
    end

    # Change the status of mocking
    # false is the default and works as expected
    # true returns a value from stubs or raises
    def mock=(new_mock)
      display_warning("Excon#mock is deprecated, pass Excon.defaults[:mock]= instead (#{caller.first})")
      self.defaults[:mock] = new_mock
    end

    # @return [String] The filesystem path to the SSL Certificate Authority
    def ssl_ca_path
      display_warning("Excon#ssl_ca_path is deprecated, use Excon.defaults[:ssl_ca_path] instead (#{caller.first})")
      self.defaults[:ssl_ca_path]
    end

    # Change path to the SSL Certificate Authority
    # @return [String] The filesystem path to the SSL Certificate Authority
    def ssl_ca_path=(new_ssl_ca_path)
      display_warning("Excon#ssl_ca_path= is deprecated, use Excon.defaults[:ssl_ca_path]= instead (#{caller.first})")
      self.defaults[:ssl_ca_path] = new_ssl_ca_path
    end

    # @return [true, false] Whether or not to verify the peer's SSL certificate / chain
    def ssl_verify_peer
      display_warning("Excon#ssl_verify_peer= is deprecated, use Excon.defaults[:ssl_verify_peer]= instead (#{caller.first})")
      self.defaults[:ssl_verify_peer]
    end

    # Change the status of ssl peer verification
    # @see Excon#ssl_verify_peer (attr_reader)
    def ssl_verify_peer=(new_ssl_verify_peer)
      display_warning("Excon#ssl_verify_peer is deprecated, use Excon.defaults[:ssl_verify_peer] instead (#{caller.first})")
      self.defaults[:ssl_verify_peer] = new_ssl_verify_peer
    end

    # @see Connection#initialize
    # Initializes a new keep-alive session for a given remote host
    #   @param [String] url The destination URL
    #   @param [Hash<Symbol, >] params One or more option params to set on the Connection instance
    #   @return [Connection] A new Excon::Connection instance
    def new(url, params = {})
      uri_parser = params[:uri_parser] || Excon.defaults[:uri_parser]
      uri = uri_parser.parse(url)
      params = {
        :host       => uri.host,
        :path       => uri.path,
        :port       => uri.port.to_s,
        :query      => uri.query,
        :scheme     => uri.scheme,
        :user       => (URI.decode(uri.user) if uri.user),
        :password   => (URI.decode(uri.password) if uri.password),
      }.merge!(params)
      Excon::Connection.new(params)
    end

    # push an additional stub onto the list to check for mock requests
    #   @param [Hash<Symbol, >] request params to match against, omitted params match all
    #   @param [Hash<Symbol, >] response params to return from matched request or block to call with params
    def stub(request_params = {}, response_params = nil)
      if url = request_params.delete(:url)
        uri = URI.parse(url)
        request_params.update(
          :host              => uri.host,
          :path              => uri.path,
          :port              => uri.port.to_s,
          :query             => uri.query,
          :scheme            => uri.scheme
        )
        if uri.user || uri.password
          request_params[:headers] ||= {}
          user, pass = URI.decode_www_form_component(uri.user.to_s), URI.decode_www_form_component(uri.password.to_s)
          request_params[:headers]['Authorization'] ||= 'Basic ' << ['' << user << ':' << pass].pack('m').delete(Excon::CR_NL)
        end
      end
      if block_given?
        if response_params
          raise(ArgumentError.new("stub requires either response_params OR a block"))
        else
          stub = [request_params, Proc.new]
        end
      elsif response_params
        stub = [request_params, response_params]
      else
        raise(ArgumentError.new("stub requires either response_params OR a block"))
      end
      stubs.unshift(stub)
      stub
    end

    # get a stub matching params or nil
    def stub_for(request_params={})
      Excon.stubs.each do |stub, response|
        captures = { :headers => {} }
        headers_match = !stub.has_key?(:headers) || stub[:headers].keys.all? do |key|
          case value = stub[:headers][key]
          when Regexp
            if match = value.match(request_params[:headers][key])
              captures[:headers][key] = match.captures
            end
            match
          else
            value == request_params[:headers][key]
          end
        end
        non_headers_match = (stub.keys - [:headers]).all? do |key|
          case value = stub[key]
          when Regexp
            if match = value.match(request_params[key])
              captures[key] = match.captures
            end
            match
          else
            value == request_params[key]
          end
        end
        if headers_match && non_headers_match
          request_params[:captures] = captures
          return response
        end
      end
      nil
    end

    # get a list of defined stubs
    def stubs
      @stubs ||= []
    end

    # Generic non-persistent HTTP methods
    HTTP_VERBS.each do |method|
      module_eval <<-DEF, __FILE__, __LINE__ + 1
        def #{method}(url, params = {}, &block)
          new(url, params).request(:method => :#{method}, &block)
        end
      DEF
    end
  end
end
