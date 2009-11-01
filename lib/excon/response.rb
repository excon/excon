module Excon
  class Response

    attr_accessor :body, :headers, :status

    def initialize(attributes = {})
      @body    = attributes[:body] || ''
      @headers = attributes[:headers] || {}
      @status  = attributes[:status]
    end

  end
end
