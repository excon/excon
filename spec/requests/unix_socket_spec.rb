require "spec_helper"

describe Excon::Connection do
  include_context('stubs')
  context "when speaking to a UNIX socket" do
    context "Host header handling" do
      before do
        Excon.stub do |req|
          {
            body: req[:headers].to_json,
            status: 200,
          }
        end
      end
      it "sends an empty Host= by default" do
        conn = Excon::Connection.new(
          scheme: "unix",
          socket: "/tmp/x.sock",
        )

        headers = JSON.parse(conn.get(path: "/path").body)

        expect(headers["Host"]).to eq("")
      end

      it "doesn't overwrite an explicit Host header" do
        conn = Excon::Connection.new(
          scheme: "unix",
          socket: "/tmp/x.sock",
        )

        headers = JSON.parse(conn.get(path: "/path", headers: { "Host" => "localhost" }).body)

        expect(headers["Host"]).to eq("localhost")
      end
    end
  end
end
