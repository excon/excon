__DIR__ = File.dirname(__FILE__)

$LOAD_PATH.unshift __DIR__ unless
  $LOAD_PATH.include?(__DIR__) ||
  $LOAD_PATH.include?(File.expand_path(__DIR__))

require 'rubygems'
require 'openssl'
require 'socket'
require 'uri'

require 'excon/connection'
require 'excon/response'

module Excon

  def self.new(url)
    Excon::Connection.new(url)
  end

end
