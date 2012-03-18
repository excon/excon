$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'forwardable'
require 'openssl'
require 'rbconfig'
require 'socket'
require 'uri'

require 'excon/constants'
require 'excon/connection'
require 'excon/errors'
require 'excon/response'
require 'excon/socket'
require 'excon/ssl_socket'

module Excon
  class << self

    # @return [Hash] defaults for Excon connections
    def defaults
      @defaults ||= {
        :connect_timeout    => 60,
        :headers            => {},
        :instrumentor_name  => 'excon',
        :mock               => false,
        :read_timeout       => 60,
        :retry_limit        => DEFAULT_RETRY_LIMIT,
        :ssl_ca_file        => DEFAULT_CA_FILE,
        :ssl_verify_peer    => RbConfig::CONFIG['host_os'] !~ /mswin|win32|dos|cygwin|mingw/i,
        :write_timeout      => 60
      }
    end

    # Change defaults for Excon connections
    # @return [Hash] defaults for Excon connections
    def defaults=(new_defaults)
      @defaults = new_defaults
    end

    # Status of mocking
    def mock
      puts("Excon#mock is deprecated, pass Excon.defaults[:mock] instead (#{caller.first})")
      self.defaults[:mock]
    end

    # Change the status of mocking
    # false is the default and works as expected
    # true returns a value from stubs or raises
    def mock=(new_mock)
      puts("Excon#mock is deprecated, pass Excon.defaults[:mock]= instead (#{caller.first})")
      self.defaults[:mock] = new_mock
    end

    # @return [String] The filesystem path to the SSL Certificate Authority
    def ssl_ca_path
      puts("Excon#ssl_ca_path is deprecated, use Excon.defaults[:ssl_ca_path] instead (#{caller.first})")
      self.defaults[:ssl_ca_path]
    end

    # Change path to the SSL Certificate Authority
    # @return [String] The filesystem path to the SSL Certificate Authority
    def ssl_ca_path=(new_ssl_ca_path)
      puts("Excon#ssl_ca_path= is deprecated, use Excon.defaults[:ssl_ca_path]= instead (#{caller.first})")
      self.defaults[:ssl_ca_path] = new_ssl_ca_path
    end

    # @return [true, false] Whether or not to verify the peer's SSL certificate / chain
    def ssl_verify_peer
      puts("Excon#ssl_verify_peer= is deprecated, use Excon.defaults[:ssl_verify_peer]= instead (#{caller.first})")
      self.defaults[:ssl_verify_peer]
    end

    # Change the status of ssl peer verification
    # @see Excon#ssl_verify_peer (attr_reader)
    def ssl_verify_peer=(new_ssl_verify_peer)
      puts("Excon#ssl_verify_peer is deprecated, use Excon.defaults[:ssl_verify_peer] instead (#{caller.first})")
      self.defaults[:ssl_verify_peer] = new_ssl_verify_peer
    end

    # @see Connection#initialize
    # Initializes a new keep-alive session for a given remote host
    #   @param [String] url The destination URL
    #   @param [Hash<Symbol, >] params One or more option params to set on the Connection instance
    #   @return [Connection] A new Excon::Connection instance
    def new(url, params = {})
      Excon::Connection.new(url, params)
    end

    # push an additional stub onto the list to check for mock requests
    #   @param [Hash<Symbol, >] request params to match against, omitted params match all
    #   @param [Hash<Symbol, >] response params to return from matched request or block to call with params
    def stub(request_params, response_params = nil)
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
      stubs << stub
      stub
    end

    # get a list of defined stubs
    def stubs
      @stubs ||= []
    end

    # Generic non-persistent HTTP methods
    HTTP_VERBS.each do |method|
      eval <<-DEF
        def #{method}(url, params = {}, &block)
          new(url).request(params.merge!(:method => :#{method}), &block)
        end
      DEF
    end
  end
end
