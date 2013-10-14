module Excon
  module Utils
    extend self

    def valid_connection_keys(datum, params = {})
      Excon::VALID_CONNECTION_KEYS
    end

    def valid_request_keys(datum, params = {})
      Excon::VALID_REQUEST_KEYS
    end

    def port_string(datum)
      if datum[:port].nil? || (datum[:omit_default_port] && ((datum[:scheme].casecmp('http') == 0 && datum[:port] == 80) || (datum[:scheme].casecmp('https') == 0 && datum[:port] == 443)))
        ''
      else
        ':' << datum[:port].to_s
      end
    end
  end
end
