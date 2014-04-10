module Excon
  class Headers < Hash

    alias_method :raw_writer, :[]=
    alias_method :raw_reader, :[]

    def [](key)
      value = raw_reader(key)
      if value.nil?
        index_case_insensitive if @downcased.nil?
        value = @downcased[key.downcase]
      end
      value
    end

    def []=(key, value)
      raw_writer(key, value)
      @downcased[key.downcase] = value unless @downcased.nil?
    end

    alias_method :store, :[]=

    private

    def index_case_insensitive
      @downcased = {}
      each_pair do |key, value|
        @downcased[key.downcase] = value
      end
    end

  end
end
