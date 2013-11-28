module Excon
  module Utils
    extend self

    ESCAPED = /%([0-9a-fA-F]{2})/

    def valid_connection_keys(params = {})
      Excon::VALID_CONNECTION_KEYS
    end

    def valid_request_keys(params = {})
      Excon::VALID_REQUEST_KEYS
    end

    def connection_uri(datum = @data)
      unless datum
        raise ArgumentError, '`datum` must be given unless called on a Connection'
      end
      if datum[:scheme] == UNIX
        '' << datum[:scheme] << '://' << datum[:socket]
      else
        '' << datum[:scheme] << '://' << datum[:host] << port_string(datum)
      end
    end

    def request_uri(datum)
      connection_uri(datum) << datum[:path] << query_string(datum)
    end

    def port_string(datum)
      if datum[:port].nil? || (datum[:omit_default_port] && ((datum[:scheme].casecmp('http') == 0 && datum[:port] == 80) || (datum[:scheme].casecmp('https') == 0 && datum[:port] == 443)))
        ''
      else
        ':' << datum[:port].to_s
      end
    end

    def query_string(datum)
      str = ''
      case datum[:query]
      when String
        str << '?' << datum[:query]
      when Hash
        str << '?'
        datum[:query].sort_by {|k,_| k.to_s }.each do |key, values|
          if values.nil?
            str << key.to_s << '&'
          else
            [values].flatten.each do |value|
              str << key.to_s << '=' << CGI.escape(value.to_s) << '&'
            end
          end
        end
        str.chop! # remove trailing '&'
      end
      str
    end

    # Splits a header value +str+ according to HTTP specification.
    def split_header_value(str)
      return [] if str.nil?
      str = str.strip
      str.force_encoding('BINARY') if FORCE_ENC
      str.scan(%r'\G((?:"(?:\\.|[^"])+?"|[^",]+)+)
                    (?:,\s*|\Z)'xn).flatten
    end

    # Unescapes HTTP reserved and unwise characters in +str+
    def unescape_uri(str)
      str = str.dup
      str.force_encoding('BINARY') if FORCE_ENC
      str.gsub!(ESCAPED) { $1.hex.chr }
      str
    end

    # Unescape form encoded values in +str+
    def unescape_form(str)
      str = str.dup
      str.force_encoding('BINARY') if FORCE_ENC
      str.gsub!(/\+/, ' ')
      str.gsub!(ESCAPED) { $1.hex.chr }
      str
    end
  end
end
