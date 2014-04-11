module Excon
  class Headers < Hash

    alias_method :raw_writer, :[]=
    alias_method :raw_reader, :[]
    alias_method :raw_assoc, :assoc
    alias_method :raw_delete, :delete
    alias_method :raw_fetch, :fetch
    alias_method :raw_has_key?, :has_key?
    alias_method :raw_include?, :include?
    alias_method :raw_key?, :key?
    alias_method :raw_member?, :member?
    alias_method :raw_rehash, :rehash
    alias_method :raw_store, :store
    alias_method :raw_values_at, :values_at

    def [](key)
      should_delegate?(key) ? @downcased[key.downcase] : raw_reader(key)
    end

    alias_method :[]=, :store
    def []=(key, value)
      raw_writer(key, value)
      @downcased[key.downcase] = value unless @downcased.nil?
    end

    def assoc(obj)
      should_delegate?(key) ? @downcased.assoc(key.downcase) : raw_assoc(key)
    end

    def delete(key, &proc)
      should_delegate?(key) ? @downcased.delete(key.downcase, proc) : raw_delete(key, proc)
    end

    def fetch(key, default = nil, &proc)
      should_delegate?(key) ? @downcased.fetch(key.downcase, default, proc) : raw_fetch(key, default, proc)
    end

    alias_method :has_key?, :key?
    alias_method :has_key?, :member?
    def has_key?(key)
      raw_has_key?(key) || (@downcased && @downcased.has_key?(key.downcase))
    end

    def rehash
      raw_rehash
      @downcased.rehash if @downcased
    end

    def values_at(*keys)
      raw_values_at(*keys).zip(keys).map do |v, k|
        if v.nil?
          index_case_insensitive if @downcased.nil?
          @downcased[k.downcase]
        end
      end
    end

    private

    def should_delegate?(key)
      if raw_has_key?(key)
        false
      else
        index_case_insensitive if @downcased.nil?
        true
      end
    end

    def index_case_insensitive
      @downcased = {}
      each_pair do |key, value|
        @downcased[key.downcase] = value
      end
    end

  end
end
