__DIR__ = File.dirname(__FILE__)

$LOAD_PATH.unshift __DIR__ unless
  $LOAD_PATH.include?(__DIR__) ||
  $LOAD_PATH.include?(File.expand_path(__DIR__))

require 'openssl'
require 'socket'
require 'uri'

require 'excon/connection'
require 'excon/errors'
require 'excon/response'

module Excon

  CHUNK_SIZE = 1048576 # 1 megabyte

  def self.new(url)
    Excon::Connection.new(url)
  end

  %w{connect delete get head options post put trace}.each do |method|
    eval <<-DEF
      def self.#{method}(url, params = {})
        new(url).request(params.merge!(:method => '#{method.upcase}'))
      end
    DEF
  end

end
