# frozen_string_literal: true

module Excon
  module Utils
    module_function

    CONTROL   = "#{(0x0..0x1f).map(&:chr).join}\u007F"
    DELIMS    = '<>#%"'
    UNWISE    = '{}|\\^[]`'
    NONASCII  = (0x80..0xff).map(&:chr).join
    UNESCAPED = /([#{Regexp.escape("#{CONTROL} #{DELIMS}#{UNWISE}#{NONASCII}")}])/.freeze
    ESCAPED   = /%([0-9a-fA-F]{2})/.freeze

    def binary_encode(string)
      if FORCE_ENC && string.encoding != Encoding::ASCII_8BIT
        if string.frozen?
          string.dup.force_encoding('BINARY')
        else
          string.force_encoding('BINARY')
        end
      else
        string
      end
    end

    def connection_uri(datum = @data)
      raise ArgumentError, '`datum` must be given unless called on a Connection' unless datum

      if datum[:scheme] == UNIX
        "#{datum[:scheme]}://#{datum[:socket]}"
      else
        "#{datum[:scheme]}://#{datum[:host]}#{port_string(datum)}"
      end
    end

    # Redact sensitive info from provided data
    def redact(datum)
      datum = datum.dup
      if datum.key?(:headers)
        if datum[:headers].key?('Authorization') || datum[:headers].key?('Proxy-Authorization')
          datum[:headers] = datum[:headers].dup
        end
        datum[:headers]['Authorization'] = REDACTED if datum[:headers].key?('Authorization')
        datum[:headers]['Proxy-Authorization'] = REDACTED if datum[:headers].key?('Proxy-Authorization')
      end
      datum[:password] = REDACTED if datum.key?(:password)
      if datum.key?(:proxy) && datum[:proxy]&.key?(:password)
        datum[:proxy] = datum[:proxy].dup
        datum[:proxy][:password] = REDACTED
      end
      datum
    end

    def request_uri(datum)
      connection_uri(datum) + datum[:path] + query_string(datum)
    end

    def port_string(datum)
      if !default_port?(datum) || datum[:include_default_port] || !datum[:omit_default_port]
        ":#{datum[:port]}"
      else
        ''
      end
    end

    def default_port?(datum)
      (!datum[:scheme]&.casecmp?('unix') && datum[:port].nil?) ||
        (datum[:scheme]&.casecmp?('http') && datum[:port] == 80) ||
        (datum[:scheme]&.casecmp?('https') && datum[:port] == 443)
    end

    def query_string(datum)
      str = +''
      case datum[:query]
      when String
        str << '?' << datum[:query]
      when Hash
        str << '?'
        datum[:query].sort_by { |k, _| k.to_s }.each do |key, values|
          key = CGI.escape(key.to_s)
          if values.nil?
            str << key << '&'
          else
            [values].flatten.each do |value|
              str << key << '=' << CGI.escape(value.to_s) << '&'
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

      str = str.dup.strip
      str = binary_encode(str)
      str.scan(/\G((?:"(?:\\.|[^"])+?"|[^",])+)
                    (?:,\s*|\Z)/xn).flatten
    end

    # Escapes HTTP reserved and unwise characters in +str+
    def escape_uri(str)
      str = str.dup
      str = binary_encode(str)
      str.gsub(UNESCAPED) { format('%%%02X', ::Regexp.last_match(1)[0].ord) }
    end

    # Unescapes HTTP reserved and unwise characters in +str+
    def unescape_uri(str)
      str = str.dup
      str = binary_encode(str)
      str.gsub(ESCAPED) { ::Regexp.last_match(1).hex.chr }
    end

    # Unescape form encoded values in +str+
    def unescape_form(str)
      str = str.dup
      str = binary_encode(str)
      str.tr!('+', ' ')
      str.gsub(ESCAPED) { ::Regexp.last_match(1).hex.chr }
    end

    # Performs validation on the passed header hash and returns a string representation of the headers
    def headers_hash_to_s(headers)
      headers_str = +''
      headers.each do |key, values|
        if key.to_s.match?(/[\r\n]/)
          raise Excon::Errors::InvalidHeaderKey, "#{key.to_s.inspect} contains forbidden \"\\r\" or \"\\n\""
        end

        [values].flatten.each do |value|
          if value.to_s.match?(/[\r\n]/)
            # Don't include the potentially sensitive header value (i.e. authorization token) in the message
            raise Excon::Errors::InvalidHeaderValue, "#{key} header value contains forbidden \"\\r\" or \"\\n\""
          end

          headers_str << key.to_s << ': ' << value.to_s << CR_NL
        end
      end
      headers_str
    end
  end
end
