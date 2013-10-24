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

    def build_query(datum)
      case datum[:query]
      when String
        '?' << datum[:query]
      when Hash
        request = '?'
        datum[:query].each do |key, values|
          if values.nil?
            request << key.to_s << '&'
          else
            [values].flatten.each do |value|
              request << key.to_s << '=' << CGI.escape(value.to_s) << '&'
            end
          end
        end
        request.chop! # remove trailing '&'
      else
        ""
      end
    end

    def formatted_uri(datum)
      if datum[:scheme] == UNIX
        "#{datum[:scheme]}://#{datum[:socket]}#{datum[:path]}#{build_query(datum)}"
      else
        "#{datum[:scheme]}://#{datum[:host]}:#{datum[:port]}#{datum[:path]}#{build_query(datum)}"
      end
    end
  end
end
