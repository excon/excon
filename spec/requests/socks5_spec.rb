# frozen_string_literal: true

require 'spec_helper'
require 'support/fake_socks5_server'
require 'webrick'
require 'webrick/https'

describe 'SOCKS5 proxy support' do

  # --- Unit tests for proxy string parsing ---
  describe Excon::SOCKS5 do
    let(:parser) { Class.new { include Excon::SOCKS5 }.new }

    describe '#parse_socks5_proxy' do
      it 'parses host:port' do
        host, port, user, pass = parser.send(:parse_socks5_proxy, 'proxy.example.com:1080')
        expect(host).to eq('proxy.example.com')
        expect(port).to eq('1080')
        expect(user).to be_nil
        expect(pass).to be_nil
      end

      it 'defaults port to 1080' do
        host, port, _, _ = parser.send(:parse_socks5_proxy, 'proxy.example.com')
        expect(host).to eq('proxy.example.com')
        expect(port).to eq('1080')
      end

      it 'parses user:pass@host:port' do
        host, port, user, pass = parser.send(:parse_socks5_proxy, 'myuser:mypass@proxy.example.com:1080')
        expect(host).to eq('proxy.example.com')
        expect(port).to eq('1080')
        expect(user).to eq('myuser')
        expect(pass).to eq('mypass')
      end

      it 'parses socks5://host:port' do
        host, port, user, pass = parser.send(:parse_socks5_proxy, 'socks5://proxy.example.com:1080')
        expect(host).to eq('proxy.example.com')
        expect(port).to eq('1080')
        expect(user).to be_nil
        expect(pass).to be_nil
      end

      it 'parses socks5://user:pass@host:port' do
        host, port, user, pass = parser.send(:parse_socks5_proxy, 'socks5://myuser:mypass@proxy.example.com:9050')
        expect(host).to eq('proxy.example.com')
        expect(port).to eq('9050')
        expect(user).to eq('myuser')
        expect(pass).to eq('mypass')
      end

      it 'handles passwords containing colons' do
        _, _, user, pass = parser.send(:parse_socks5_proxy, 'user:p:a:ss@host:1080')
        expect(user).to eq('user')
        expect(pass).to eq('p:a:ss')
      end
    end
  end

  # --- Validation: :socks5_proxy is a valid connection key ---
  describe 'connection parameter validation' do
    it 'accepts :socks5_proxy as a valid connection key' do
      expect {
        Excon.new('http://example.com', socks5_proxy: 'localhost:1080', mock: true)
      }.not_to raise_error
    end
  end

  # --- Class hierarchy ---
  describe 'class hierarchy' do
    it 'SOCKS5Socket inherits from Excon::Socket' do
      expect(Excon::SOCKS5Socket.superclass).to eq(Excon::Socket)
    end

    it 'SOCKS5SSLSocket inherits from Excon::SSLSocket' do
      expect(Excon::SOCKS5SSLSocket.superclass).to eq(Excon::SSLSocket)
    end
  end

  # --- Integration tests ---
  context 'integration' do
    cert_dir = File.expand_path('../../../tests/data', __FILE__)

    before(:all) do
      @cert_dir = File.expand_path('../../../tests/data', __FILE__)

      # HTTP backend
      @webrick = WEBrick::HTTPServer.new(
        Port: 0,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: []
      )
      @webrick.mount_proc('/content-length/100') do |_req, res|
        res.body = 'x' * 100
      end
      @webrick.mount_proc('/echo') do |req, res|
        res.body = req.body || ''
      end
      @backend_port = @webrick.config[:Port]
      @webrick_thread = Thread.new { @webrick.start }

      # HTTPS backend
      @webrick_ssl = WEBrick::HTTPServer.new(
        Port: 0,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: [],
        SSLEnable: true,
        SSLCertName: [['CN', '127.0.0.1']],
        SSLCertificate: OpenSSL::X509::Certificate.new(File.read(File.join(@cert_dir, '127.0.0.1.cert.crt'))),
        SSLPrivateKey: OpenSSL::PKey::RSA.new(File.read(File.join(@cert_dir, '127.0.0.1.cert.key')))
      )
      @webrick_ssl.mount_proc('/content-length/100') do |_req, res|
        res.body = 'x' * 100
      end
      @webrick_ssl.mount_proc('/echo') do |req, res|
        res.body = req.body || ''
      end
      @ssl_port = @webrick_ssl.config[:Port]
      @webrick_ssl_thread = Thread.new { @webrick_ssl.start }

      # Shared no-auth SOCKS5 proxy (used by most tests)
      @socks5 = Excon::Test::FakeSOCKS5Server.new
      @socks5.start
    end

    after(:all) do
      @socks5&.stop
      @webrick&.shutdown
      @webrick_thread&.join(2)
      @webrick_ssl&.shutdown
      @webrick_ssl_thread&.join(2)
    end

    # --- HTTP through SOCKS5 (no auth) ---

    it 'makes a successful GET request' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.status).to eq(200)
      expect(response.body).to eq('x' * 100)
    end

    it 'tracks remote_ip from the proxy connection' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.remote_ip).to eq('127.0.0.1')
    end

    it 'forwards POST request bodies' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      response = conn.request(method: :post, path: '/echo', body: 'hello SOCKS5')
      expect(response.status).to eq(200)
      expect(response.body).to eq('hello SOCKS5')
    end

    it 'works with nonblock: false' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}",
        nonblock: false
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.status).to eq(200)
      expect(response.body).to eq('x' * 100)
    end

    it 'supports multiple requests on a persistent connection' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}",
        persistent: true
      )
      r1 = conn.request(method: :get, path: '/content-length/100')
      r2 = conn.request(method: :post, path: '/echo', body: 'second')
      expect(r1.status).to eq(200)
      expect(r1.body).to eq('x' * 100)
      expect(r2.status).to eq(200)
      expect(r2.body).to eq('second')
      conn.reset
    end

    # --- HTTP through SOCKS5 (with auth) ---

    context 'with username/password authentication' do
      before(:all) do
        @socks5_auth = Excon::Test::FakeSOCKS5Server.new(
          username: 'testuser',
          password: 'testpass'
        )
        @socks5_auth.start
      end
      after(:all) { @socks5_auth&.stop }

      it 'authenticates and makes a successful request' do
        conn = Excon.new(
          "http://127.0.0.1:#{@backend_port}",
          socks5_proxy: "testuser:testpass@127.0.0.1:#{@socks5_auth.port}"
        )
        response = conn.request(method: :get, path: '/content-length/100')
        expect(response.status).to eq(200)
        expect(response.body).to eq('x' * 100)
      end

      it 'works with socks5:// URI scheme' do
        conn = Excon.new(
          "http://127.0.0.1:#{@backend_port}",
          socks5_proxy: "socks5://testuser:testpass@127.0.0.1:#{@socks5_auth.port}"
        )
        response = conn.request(method: :get, path: '/content-length/100')
        expect(response.status).to eq(200)
      end

      it 'raises an error with wrong credentials' do
        conn = Excon.new(
          "http://127.0.0.1:#{@backend_port}",
          socks5_proxy: "wrong:creds@127.0.0.1:#{@socks5_auth.port}"
        )
        expect { conn.request(method: :get, path: '/') }.to raise_error(
          Excon::Errors::SocketError, /SOCKS5 proxy authentication failed/
        )
      end
    end

    # --- HTTPS through SOCKS5 ---

    it 'makes a successful HTTPS request through the SOCKS5 proxy' do
      conn = Excon.new(
        "https://127.0.0.1:#{@ssl_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}",
        ssl_verify_peer: false
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.status).to eq(200)
      expect(response.body).to eq('x' * 100)
    end

    it 'forwards POST bodies over HTTPS' do
      conn = Excon.new(
        "https://127.0.0.1:#{@ssl_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}",
        ssl_verify_peer: false
      )
      response = conn.request(method: :post, path: '/echo', body: 'encrypted payload')
      expect(response.status).to eq(200)
      expect(response.body).to eq('encrypted payload')
    end

    it 'verifies the SSL peer when ssl_verify_peer is true' do
      conn = Excon.new(
        "https://127.0.0.1:#{@ssl_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}",
        ssl_verify_peer: true,
        ssl_ca_file: File.join(cert_dir, '127.0.0.1.cert.crt')
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.status).to eq(200)
    end

    # --- Error cases ---

    context 'when proxy rejects CONNECT' do
      before(:all) do
        @socks5_reject = Excon::Test::FakeSOCKS5Server.new(reject_connect: true)
        @socks5_reject.start
      end
      after(:all) { @socks5_reject&.stop }

      it 'raises an error' do
        conn = Excon.new(
          "http://127.0.0.1:#{@backend_port}",
          socks5_proxy: "127.0.0.1:#{@socks5_reject.port}"
        )
        expect { conn.request(method: :get, path: '/') }.to raise_error(
          Excon::Errors::SocketError, /SOCKS5 proxy connect failed/
        )
      end
    end

    it 'raises an error when proxy is unreachable' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: '127.0.0.1:1',
        connect_timeout: 1
      )
      expect { conn.request(method: :get, path: '/') }.to raise_error(Excon::Error)
    end

    it 'raises an error when hostname exceeds 255 bytes' do
      long_host = 'a' * 256 + '.example.com'
      conn = Excon::Connection.new(
        host: long_host,
        hostname: long_host,
        port: @backend_port,
        scheme: 'http',
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      expect { conn.request(method: :get, path: '/') }.to raise_error(
        Excon::Errors::SocketError, /hostname exceeds maximum length/
      )
    end

    # --- Edge cases ---

    it 'gives SOCKS5 precedence when both :proxy and :socks5_proxy are set' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        proxy: 'http://bogus-proxy.invalid:9999',
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      response = conn.request(method: :get, path: '/content-length/100')
      expect(response.status).to eq(200)
    end

    it 'clears :proxy from data after connect so requests use relative URIs' do
      conn = Excon.new(
        "http://127.0.0.1:#{@backend_port}",
        socks5_proxy: "127.0.0.1:#{@socks5.port}"
      )
      conn.request(method: :get, path: '/content-length/100')
      expect(conn.data[:proxy]).to be_nil
    end
  end
end
