module Excon
  module Middleware
    class RedirectFollower < Excon::Middleware::Base
      def response_call(datum)
        if datum.has_key?(:response) && [:get, :head].include?(datum[:method].to_s.downcase.to_sym)
          case datum[:response][:status]
          when 301, 302, 303, 307
            uri_parser = datum[:uri_parser] || Excon.defaults[:uri_parser]
            _, location = datum[:response][:headers].detect do |key, value|
              key.casecmp('Location') == 0
            end
            uri = uri_parser.parse(location)

            port_string = if datum[:omit_default_port] && ((uri.scheme.casecmp('http') == 0 && uri.port.to_i == 80) || (uri.scheme.casecmp('https') == 0 && uri.port.to_i == 443))
              ''
            else
              ':' << uri.port.to_s
            end

            # delete old/redirect response
            datum.delete(:response)

            response = datum[:connection].request(datum.merge!(
                :headers    => (datum[:headers] || {}).merge({'Host' => '' << uri.host << port_string}),
                :host       => uri.host,
                :path       => uri.path,
                :port       => uri.port,
                :query      => uri.query,
                :scheme     => uri.scheme,
                :user       => (URI.decode(uri.user) if uri.user),
                :password   => (URI.decode(uri.password) if uri.password),
            ))
            datum.merge!({:response => response.data})
          else
            @stack.response_call(datum)
          end
        else
          @stack.response_call(datum)
        end
      end
    end
  end
end
