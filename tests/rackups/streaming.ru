use Rack::ContentType, "text/plain"

app = lambda do |env|
  response_headers = {}
  response_headers["rack.hijack"] = lambda do |io|
    # Write directly to IO of the response
    begin
      ['Hello','streamy','world'].each do |x|
        io.write(x)
        io.flush
        sleep 1
      end
    ensure
      io.close
    end
  end
  [200, response_headers, nil]
end

run app
