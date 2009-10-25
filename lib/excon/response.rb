module Excon
  class Response

    attr_accessor :body, :headers, :status

    def initialize
      @body = ''
      @headers = {}
    end

  end
end
