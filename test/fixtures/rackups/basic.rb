# frozen_string_literal: true

require 'json'
require 'rack'

# Basic server defines requests/responses for testing
class Basic
  CONTENT_TYPE = { 'content-type' => 'text/html;charset=utf-8' }.freeze

  def self.call(env)
    new.call(env)
  end

  def call(env)
    request = Rack::Request.new(env)
    # GET routes also answer HEAD; the server drops the body
    method = request.head? ? 'GET' : request.request_method

    case [method, Rack::Utils.unescape_path(request.path_info)]
    in ['GET', '/']
      ok('GET /')
    in ['GET', %r{\A/content-length/([^/]+)\z}]
      ok('x' * Regexp.last_match(1).to_i, 'custom' => 'Foo: bar')
    in ['GET', '/headers']
      ok(env.select { |key, _| key.start_with?('HTTP_') }.to_json, 'content-type' => 'application/json')
    in ['POST', '/body-sink']
      ok(request.body.read.size.to_s)
    in ['POST' | 'PUT', '/echo'] | ['GET', '/echo dirty']
      ok(request.body.read)
    in ['GET', '/foo']
      ok('foo')
    in ['GET', '/bar']
      ok('bar')
    else
      [404, { 'content-type' => 'text/plain' }, ['Not Found']]
    end
  end

  private

  def ok(body, headers = {})
    [200, CONTENT_TYPE.merge(headers), [body]]
  end
end
