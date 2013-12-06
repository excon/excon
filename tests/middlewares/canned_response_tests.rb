Shindo.tests("Excon support for middlewares that return canned responses") do
  the_body = "canned"

  canned_response_middleware = Class.new(Excon::Middleware::Base) do
    define_method :request_call do |params|
      params[:response] = {
        :body     => the_body,
        :headers  => {},
        :status   => 200
      }
      super(params)
    end
  end

  tests('does not mutate the canned response body').returns("canned") do
    Excon.get(
      'http://some-host.com/some-path',
      :middlewares    => [canned_response_middleware] + Excon.defaults[:middlewares],
      :response_block => Proc.new { } # to force streaming
    )
    the_body
  end
end

