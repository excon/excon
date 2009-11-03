__DIR__ = File.dirname(__FILE__)

$LOAD_PATH.unshift __DIR__ unless
  $LOAD_PATH.include?(__DIR__) ||
  $LOAD_PATH.include?(File.expand_path(__DIR__))

require 'openssl'
require 'socket'
require 'uri'

require 'excon/errors'
require 'excon/response'

module Excon

  CHUNK_SIZE = 1048576 # 1 megabyte

  def self.reload
    load 'excon/connection.rb'
  end

  def self.mock!
    @mocking = true
    @mocks = {}

    def self.mocks
      @mocks
    end

    self.reload
  end

  def self.mocking?
    !!@mocking
  end

  def self.new(url)
    Excon::Connection.new(url)
  end

end

Excon.reload
