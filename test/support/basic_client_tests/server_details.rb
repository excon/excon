# frozen_string_literal: true

require 'time'
require_relative 'check'

module BasicClientTests
  # What WEBrick over TCP adds to a response. Left out where the server or
  # transport can't provide it (see BasicUnixSocketTest).
  module ServerDetails
    extend Check

    check 'get_returns_a_date_header' do |options|
      assert_instance_of Time, Time.parse(get_content(options).headers['Date'])
    end

    check 'get_returns_a_webrick_server_header' do |options|
      assert_match(/^WEBrick/, get_content(options).headers['Server'])
    end

    check 'get_returns_the_remote_ip' do |options|
      assert_equal '127.0.0.1', get_content(options).remote_ip
    end
  end
end
