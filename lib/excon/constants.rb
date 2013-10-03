module Excon

  VERSION = '0.26.0'

  CR_NL = "\r\n"

  DEFAULT_CA_FILE = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "cacert.pem"))

  DEFAULT_CHUNK_SIZE = 1048576 # 1 megabyte

  # avoid overwrite if somebody has redefined
  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = DEFAULT_CHUNK_SIZE
  end

  DEFAULT_NONBLOCK = OpenSSL::SSL::SSLSocket.public_method_defined?(:connect_nonblock) &&
    OpenSSL::SSL::SSLSocket.public_method_defined?(:read_nonblock) &&
    OpenSSL::SSL::SSLSocket.public_method_defined?(:write_nonblock)

  DEFAULT_RETRY_LIMIT = 4

  FORCE_ENC = CR_NL.respond_to?(:force_encoding)

  HTTP_1_1 = " HTTP/1.1\r\n"

  HTTP_VERBS = %w{connect delete get head options patch post put trace}

  HTTPS = 'https'

  NO_ENTITY = [204, 205, 304].freeze

  REDACTED = 'REDACTED'

  UNIX = 'unix'

  USER_AGENT = 'excon/' << VERSION

  VALID_CONNECTION_KEYS = [
    :body,
    :captures,
    :chunk_size,
    :ciphers,
    :client_key,
    :client_cert,
    :certificate,
    :certificate_path,
    :private_key,
    :private_key_path,
    :connect_timeout,
    :connection,
    :debug_request,
    :debug_response,
    :error,
    :exception,
    :expects,
    :family,
    :headers,
    :host,
    :idempotent,
    :instrumentor,
    :instrumentor_name,
    :method,
    :middlewares,
    :mock,
    :nonblock,
    :omit_default_port,
    :password,
    :path,
    :pipeline,
    :port,
    :proxy,
    :query,
    :read_timeout,
    :request_block,
    :response,
    :response_block,
    :retries_remaining,
    :retry_limit,
    :scheme,
    :socket,
    :tcp_nodelay,
    :uri_parser,
    :user,
    :ssl_ca_file,
    :ssl_verify_peer,
    :stack,
    :write_timeout
  ]

  unless ::IO.const_defined?(:WaitReadable)
    class ::IO
      module WaitReadable; end
    end
  end

  unless ::IO.const_defined?(:WaitWritable)
    class ::IO
      module WaitWritable; end
    end
  end

end
