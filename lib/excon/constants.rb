module Excon
  unless const_defined?(:VERSION)
    VERSION = '0.7.8'
  end

  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = 1048576 # 1 megabyte
  end

  unless const_defined?(:HTTP_VERBS)
    HTTP_VERBS = %w{connect delete get head options post put trace}
  end

  unless const_defined?(:DEFAULT_RETRY_LIMIT)
    DEFAULT_RETRY_LIMIT = 4
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
