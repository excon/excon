module Excon
  module Errors

    class Error < StandardError; end

    class SocketError < Error
      attr_reader :socket_error

      def initialize(socket_error=nil)
        if socket_error.message =~ /certificate verify failed/
          super('Unable to verify certificate, please set `Excon.ssl_ca_path = path_to_certs` or `Excon.ssl_verify_peer = false` (less secure).')
        else
          super(socket_error.message)
        end
        set_backtrace(socket_error.backtrace)
        @socket_error = socket_error
      end
    end

    class ProxyParseError < Error; end

    class StubNotFound < Error; end

    class HTTPStatusError < Error
      attr_reader :request, :response

      def initialize(msg, request = nil, response = nil)
        super(msg)
        @request = request
        @response = response
      end
    end

    class Continue < HTTPStatusError; end                     # 100
    class SwitchingProtocols < HTTPStatusError; end           # 101
    class OK < HTTPStatusError; end                           # 200
    class Created < HTTPStatusError; end                      # 201
    class Accepted < HTTPStatusError; end                     # 202
    class NonAuthoritativeInformation < HTTPStatusError; end  # 203
    class NoContent < HTTPStatusError; end                    # 204
    class ResetContent < HTTPStatusError; end                 # 205
    class PartialContent < HTTPStatusError; end               # 206
    class MultipleChoices < HTTPStatusError; end              # 300
    class MovedPermanently < HTTPStatusError; end             # 301
    class Found < HTTPStatusError; end                        # 302
    class SeeOther < HTTPStatusError; end                     # 303
    class NotModified < HTTPStatusError; end                  # 304
    class UseProxy < HTTPStatusError; end                     # 305
    class TemporaryRedirect < HTTPStatusError; end            # 307
    class BadRequest < HTTPStatusError; end                   # 400
    class Unauthorized < HTTPStatusError; end                 # 401
    class PaymentRequired < HTTPStatusError; end              # 402
    class Forbidden < HTTPStatusError; end                    # 403
    class NotFound < HTTPStatusError; end                     # 404
    class MethodNotAllowed < HTTPStatusError; end             # 405
    class NotAcceptable < HTTPStatusError; end                # 406
    class ProxyAuthenticationRequired < HTTPStatusError; end  # 407
    class RequestTimeout < HTTPStatusError; end               # 408
    class Conflict < HTTPStatusError; end                     # 409
    class Gone < HTTPStatusError; end                         # 410
    class LengthRequired < HTTPStatusError; end               # 411
    class PreconditionFailed < HTTPStatusError; end           # 412
    class RequestEntityTooLarge < HTTPStatusError; end        # 413
    class RequestURITooLong < HTTPStatusError; end            # 414
    class UnsupportedMediaType < HTTPStatusError; end         # 415
    class RequestedRangeNotSatisfiable < HTTPStatusError; end # 416
    class ExpectationFailed < HTTPStatusError; end            # 417
    class UnprocessableEntity < HTTPStatusError; end          # 422
    class InternalServerError < HTTPStatusError; end          # 500
    class NotImplemented < HTTPStatusError; end               # 501
    class BadGateway < HTTPStatusError; end                   # 502
    class ServiceUnavailable < HTTPStatusError; end           # 503
    class GatewayTimeout < HTTPStatusError; end               # 504

    # Messages for nicer exceptions, from rfc2616
    def self.status_error(request, response)
      @errors ||= { 
        100 => [Excon::Errors::Continue, 'Continue'],
        101 => [Excon::Errors::SwitchingProtocols, 'Switching Protocols'],
        200 => [Excon::Errors::OK, 'OK'],
        201 => [Excon::Errors::Created, 'Created'],
        202 => [Excon::Errors::Accepted, 'Accepted'],
        203 => [Excon::Errors::NonAuthoritativeInformation, 'Non-Authoritative Information'],
        204 => [Excon::Errors::NoContent, 'No Content'],
        205 => [Excon::Errors::ResetContent, 'Reset Content'],
        206 => [Excon::Errors::PartialContent, 'Partial Content'],
        300 => [Excon::Errors::MultipleChoices, 'Multiple Choices'],
        301 => [Excon::Errors::MovedPermanently, 'Moved Permanently'],
        302 => [Excon::Errors::Found, 'Found'],
        303 => [Excon::Errors::SeeOther, 'See Other'],
        304 => [Excon::Errors::NotModified, 'Not Modified'],
        305 => [Excon::Errors::UseProxy, 'Use Proxy'],
        307 => [Excon::Errors::TemporaryRedirect, 'Temporary Redirect'],
        400 => [Excon::Errors::BadRequest, 'Bad Request'],
        401 => [Excon::Errors::Unauthorized, 'Unauthorized'],
        402 => [Excon::Errors::PaymentRequired, 'Payment Required'],
        403 => [Excon::Errors::Forbidden, 'Forbidden'],
        404 => [Excon::Errors::NotFound, 'Not Found'],
        405 => [Excon::Errors::MethodNotAllowed, 'Method Not Allowed'],
        406 => [Excon::Errors::NotAcceptable, 'Not Acceptable'],
        407 => [Excon::Errors::ProxyAuthenticationRequired, 'Proxy Authentication Required'],
        408 => [Excon::Errors::RequestTimeout, 'Request Timeout'],
        409 => [Excon::Errors::Conflict, 'Conflict'],
        410 => [Excon::Errors::Gone, 'Gone'],
        411 => [Excon::Errors::LengthRequired, 'Length Required'],
        412 => [Excon::Errors::PreconditionFailed, 'Precondition Failed'],
        413 => [Excon::Errors::RequestEntityTooLarge, 'Request Entity Too Large'],
        414 => [Excon::Errors::RequestURITooLong, 'Request-URI Too Long'],
        415 => [Excon::Errors::UnsupportedMediaType, 'Unsupported Media Type'],
        416 => [Excon::Errors::RequestedRangeNotSatisfiable, 'Request Range Not Satisfiable'],
        417 => [Excon::Errors::ExpectationFailed, 'Expectation Failed'],
        422 => [Excon::Errors::UnprocessableEntity, 'Unprocessable Entity'],
        500 => [Excon::Errors::InternalServerError, 'InternalServerError'],
        501 => [Excon::Errors::NotImplemented, 'Not Implemented'],
        502 => [Excon::Errors::BadGateway, 'Bad Gateway'],
        503 => [Excon::Errors::ServiceUnavailable, 'Service Unavailable'],
        504 => [Excon::Errors::GatewayTimeout, 'Gateway Timeout']
      }
      error, message = @errors[response.status] || [Excon::Errors::HTTPStatusError, 'Unknown']
      error.new("Expected(#{request[:expects].inspect}) <=> Actual(#{response.status} #{message})\n  request => #{request.inspect}\n  response => #{response.inspect}", request, response)
    end

  end
end
