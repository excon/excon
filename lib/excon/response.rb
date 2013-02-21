module Excon
  class Response

    attr_accessor :body, :data, :headers, :status, :remote_ip

    def initialize(params={})
      @data = {
        :body     => '',
        :headers  => {}
      }.merge(params)
      @body      = @data[:body]
      @headers   = @data[:headers]
      @status    = @data[:status]
      @remote_ip = @data[:remote_ip]
    end

    def [](key)
      @data[key]
    end

    def params
      $stderr.puts("Excon::Response#params is deprecated use Excon::Response#data instead (#{caller.first})")
      data
    end

    # Retrieve a specific header value. Header names are treated case-insensitively.
    #   @param [String] name Header name
    def get_header(name)
      headers.each do |key,value|
        if key.casecmp(name) == 0
          return value
        end
      end
      nil
    end

  end # class Response
end # module Excon
