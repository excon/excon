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

  connection = Excon.new(
    'http://some-host.com/some-path',
    :method         => :get,
    :middlewares    => [canned_response_middleware] + Excon.defaults[:middlewares],
    :response_block => Proc.new { } # to force streaming
  )

  tests('does not mutate the canned response body').returns("canned") do
    connection.request
    the_body
  end
end

