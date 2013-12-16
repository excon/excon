module Excon

  VERSION = '0.31.0'

  CR_NL = "\r\n"

  DEFAULT_CA_FILE = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "cacert.pem"))

  DEFAULT_CHUNK_SIZE = 1048576 # 1 megabyte

  # avoid overwrite if somebody has redefined
  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = DEFAULT_CHUNK_SIZE
  end

  DEFAULT_RETRY_LIMIT = 4

  FORCE_ENC = CR_NL.respond_to?(:force_encoding)

  HTTP_1_1 = " HTTP/1.1\r\n"

  HTTP_VERBS = %w{connect delete get head options patch post put trace}

  HTTPS = 'https'

  NO_ENTITY = [204, 205, 304].freeze

  REDACTED = 'REDACTED'

  UNIX = 'unix'

  USER_AGENT = 'excon/' << VERSION

  VALID_REQUEST_KEYS = [
    :body,
    :captures,
    :chunk_size,
    :debug_request,
    :debug_response,
    :expects,
    :headers,
    :idempotent,
    :instrumentor,
    :instrumentor_name,
    :method,
    :middlewares,
    :mock,
    :path,
    :persistent,
    :pipeline,
    :query,
    :read_timeout,
    :request_block,
    :response_block,
    :retries_remaining, # used internally
    :retry_limit,
    :write_timeout
  ]

  VALID_CONNECTION_KEYS = VALID_REQUEST_KEYS + [
    :ciphers,
    :client_key,
    :client_cert,
    :certificate,
    :certificate_path,
    :private_key,
    :private_key_path,
    :connect_timeout,
    :family,
    :host,
    :omit_default_port,
    :nonblock,
    :password,
    :port,
    :proxy,
    :scheme,
    :socket,
    :ssl_ca_file,
    :ssl_verify_peer,
    :ssl_version,
    :tcp_nodelay,
    :uri_parser,
    :user
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
