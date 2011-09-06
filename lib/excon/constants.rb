module Excon
  unless const_defined?(:VERSION)
    VERSION = '0.6.6'
  end

  unless const_defined?(:CHUNK_SIZE)
    CHUNK_SIZE = 1048576 # 1 megabyte
  end
  
  unless const_defined?(:HTTP_VERBS)
    HTTP_VERBS = %w{connect delete get head options post put trace}
  end
end
