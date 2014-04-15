module Excon
  class Headers < Hash

    SENTINEL = {}

    alias_method :raw_writer, :[]=
    alias_method :raw_reader, :[]
    if SENTINEL.respond_to?(:assoc)
      alias_method :raw_assoc, :assoc
    end
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
      if should_delegate?(key)
        @downcased[key.downcase]
      else
        raw_reader(key)
      end
    end

    alias_method :[]=, :store
    def []=(key, value)
      raw_writer(key, value)
      unless @downcased.nil?
        @downcased[key.downcase] = value
      end
    end

    if SENTINEL.respond_to? :assoc
      def assoc(obj)
        if should_delegate?(obj)
          @downcased.assoc(obj.downcase)
        else
          raw_assoc(obj)
        end
      end
    end

    def delete(key, &proc)
      if should_delegate?(key)
        @downcased.delete(key.downcase, &proc)
      else
        raw_delete(key, &proc)
      end
    end

    def fetch(key, default = nil, &proc)
      if should_delegate?(key)
        if proc
          @downcased.fetch(key.downcase, &proc)
        else
          @downcased.fetch(key.downcase, default)
        end
      else
        if proc
          raw_fetch(key, &proc)
        else
          raw_fetch(key, default)
        end
      end
    end

    alias_method :has_key?, :key?
    alias_method :has_key?, :member?
    def has_key?(key)
      raw_has_key?(key) || begin
        index_case_insensitive
        @downcased.has_key?(key.downcase)
      end
    end

    def rehash
      raw_rehash
      if @downcased
        @downcased.rehash
      end
    end

    def values_at(*keys)
      raw_values_at(*keys).zip(keys).map do |v, k|
        if v.nil?
          index_case_insensitive
          @downcased[k.downcase]
        end
      end
    end

    private

    def should_delegate?(key)
      if raw_has_key?(key)
        false
      else
        index_case_insensitive
        true
      end
    end

    def index_case_insensitive
      if @downcased.nil?
        @downcased = {}
        each_pair do |key, value|
          @downcased[key.downcase] = value
        end
      end
    end

  end
end
