module Excon

  module Errors
    class Continue < StandardError; end                     # 100
    class SwitchingProtocols < StandardError; end           # 101
    class OK < StandardError; end                           # 200
    class Created < StandardError; end                      # 201
    class Accepted < StandardError; end                     # 202
    class NonAuthoritativeInformation < StandardError; end  # 203
    class NoContent < StandardError; end                    # 204
    class ResetContent < StandardError; end                 # 205
    class PartialContent < StandardError; end               # 206
    class MultipleChoices < StandardError; end              # 300
    class MovedPermanently < StandardError; end             # 301
    class Found < StandardError; end                        # 302
    class SeeOther < StandardError; end                     # 303
    class NotModified < StandardError; end                  # 304
    class UseProxy < StandardError; end                     # 305
    class TemporaryRedirect < StandardError; end            # 307
    class BadRequest < StandardError; end                   # 400
    class Unauthorized < StandardError; end                 # 401
    class PaymentRequired < StandardError; end              # 402
    class Forbidden < StandardError; end                    # 403
    class NotFound < StandardError; end                     # 404
    class MethodNotAllowed < StandardError; end             # 405
    class NotAcceptable < StandardError; end                # 406
    class ProxyAuthenticationRequired < StandardError; end  # 407
    class RequestTimeout < StandardError; end               # 408
    class Conflict < StandardError; end                     # 409
    class Gone < StandardError; end                         # 410
    class LengthRequired < StandardError; end               # 411
    class PreconditionFailed < StandardError; end           # 412
    class RequestEntityTooLarge < StandardError; end        # 412
    class RequestURITooLong < StandardError; end            # 414
    class UnsupportedMediaType < StandardError; end         # 415
    class RequestedRangeNotSatisfiable < StandardError; end # 416
    class ExpectationFailed < StandardError; end            # 417
    class InternalServerError < StandardError; end          # 500
    class NotImplemented < StandardError; end               # 501
    class BadGateway < StandardError; end                   # 502
    class ServiceUnavailable < StandardError; end           # 503
    class GatewayTimeout < StandardError; end               # 504

    # Messages for nicer exceptions, from rfc2616
    def self.status_error(expected, actual, response)
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
        500 => [Excon::Errors::InternalServerError, 'InternalServerError'],
        501 => [Excon::Errors::NotImplemented, 'Not Implemented'],
        502 => [Excon::Errors::BadGateway, 'Bad Gateway'],
        503 => [Excon::Errors::ServiceUnavailable, 'Service Unavailable'],
        504 => [Excon::Errors::GatewayTimeout, 'Gateway Timeout']
      }
      error = @errors[actual]
      error[0].new("Expected(#{expected.inspect}) <=> Actual(#{actual} #{error[1]]}): #{response.body}")
    end

  end
end