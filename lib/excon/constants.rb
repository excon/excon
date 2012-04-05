module Excon
  unless const_defined?(:VERSION)
    VERSION = '0.13.3'
  end

  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = 1048576 # 1 megabyte
  end

  unless const_defined?(:CR_NL)
    CR_NL = "\r\n"
  end

  unless const_defined?(:DEFAULT_CA_FILE)
    DEFAULT_CA_FILE = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "cacert.pem"))
  end

  unless const_defined?(:DEFAULT_RETRY_LIMIT)
    DEFAULT_RETRY_LIMIT = 4
  end

  unless const_defined?(:FORCE_ENC)
    FORCE_ENC = CR_NL.respond_to?(:force_encoding)
  end

  unless const_defined?(:HTTP_1_1)
    HTTP_1_1 = " HTTP/1.1\r\n"
  end

  unless const_defined?(:HTTP_VERBS)
    HTTP_VERBS = %w{connect delete get head options post put trace}
  end

  unless const_defined?(:HTTPS)
    HTTPS = 'https'
  end

  unless const_defined?(:NO_ENTITY)
    NO_ENTITY = [204, 205, 304].freeze
  end

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
