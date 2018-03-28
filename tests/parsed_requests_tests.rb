# frozen_string_literal: true

require 'yaml'

class RequestInstrumentor
  class << self
    attr_accessor :events, :requests

    def instrument(name, _params = {})
      @events   ||= []
      @requests ||= []
      @events << name

      res = yield if block_given?
      @requests << res[:parsed_request] if res[:parsed_request]

      res
    end

    def reset!
      @events   = []
      @requests = []
    end

    def stats
      [events, requests]
    end
  end
end

Shindo.tests('Parsed Request Tests') do
  before { RequestInstrumentor.reset! }
  with_server('good') do
    url     = 'http://127.0.0.1:9292'
    options = { instrumentor: RequestInstrumentor }
    body    = 'GET /echo/request_count HTTP/1.1' + Excon::CR_NL +
              'User-Agent: excon/0.62.0' + Excon::CR_NL +
              'Host: 127.0.0.1:9292' + Excon::CR_NL + Excon::CR_NL

    returns([%w[excon.request excon.response], [body, body]], 'with keep_parsed_request = true') do
      Excon.new(url, options.merge(keep_parsed_request: true))
           .request(method: :get, path: '/echo/request_count')
      RequestInstrumentor.stats
    end

    returns([%w[excon.request excon.response], []], 'without keep_parsed_request = false') do
      Excon.new(url, options.merge(keep_parsed_request: false))
           .request(method: :get, path: '/echo/request_count')
      RequestInstrumentor.stats
    end
  end
end
