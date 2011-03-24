$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'openssl'
require 'rbconfig'
require 'socket'
require 'uri'

require 'excon/connection'
require 'excon/errors'
require 'excon/response'

module Excon
  unless const_defined?(:VERSION)
    VERSION = '0.5.8'
  end

  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = 1048576 # 1 megabyte
  end

  class << self
    # @return [String] The filesystem path to the SSL Certificate Authority
    attr_accessor :ssl_ca_path

    # @return [true, false] Whether or not to verify the peer's SSL certificate / chain
    attr_reader :ssl_verify_peer

    # setup ssl defaults based on platform
    @ssl_verify_peer = Config::CONFIG['host_os'] !~ /mswin|win32|dos|cygwin|mingw/i

    # @see Connection#initialize
    # Initializes a new keep-alive session for a given remote host
    #   @param [String] url The destination URL
    #   @param [Hash<Symbol, >] params One or more option params to set on the Connection instance
    #   @return [Connection] A new Excon::Connection instance
    def new(url, params = {})
      Excon::Connection.new(url, params)
    end

    # Change the status of ssl peer verification
    # @see Excon#ssl_verify_peer (attr_reader)
    def ssl_verify_peer=(new_ssl_verify_peer)
      @ssl_verify_peer = new_ssl_verify_peer && true || false
    end

    # Generic non-persistent HTTP methods
    %w{connect delete get head options post put trace}.each do |method|
      eval <<-DEF
        def #{method}(url, params = {}, &block)
          new(url).request(params.merge!(:method => :#{method}), &block)
        end
      DEF
    end
  end
end
