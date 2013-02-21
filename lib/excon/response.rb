module Excon
  class Response

    attr_accessor :data

    # backwards compatability reader/writers
    def body=(new_body)
      @data[:body] = new_body
    end
    def body
      @data[:body]
    end
    def headers=(new_headers)
      @data[:headers] = new_headers
    end
    def headers
      @data[:headers]
    end
    def status=(new_status)
      @data[:status] = new_status
    end
    def status
      @data[:status]
    end
    def remote_ip=(new_remote_ip)
      @data[:remote_ip] = new_remote_ip
    end
    def remote_ip
      @data[:remote_ip]
    end

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
