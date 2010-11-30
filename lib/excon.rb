$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'openssl'
require 'socket'
require 'uri'

require 'excon/connection'
require 'excon/errors'
require 'excon/response'

module Excon

  unless const_defined?(:VERSION)
    VERSION = '0.2.8'
  end

  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = 1048576 # 1 megabyte
  end

  # @see Connection#initialize
  #  Initializes a new keep-alive session for a given remote host
  #
  #   @param [String] url The destination URL
  #   @param [Hash<Symbol, >] params One or more option params to set on the Connection instance
  #   @return [Connection] A new Excon::Connection instance
  def self.new(url, params = {})
    Excon::Connection.new(url, params)
  end

  %w{connect delete get head options post put trace}.each do |method|
    eval <<-DEF
      def self.#{method}(url, params = {}, &block)
        new(url).request(params.merge!(:method => :#{method}), &block)
      end
    DEF
  end

end
