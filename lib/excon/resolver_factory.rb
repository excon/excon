# frozen_string_literal: true
module Excon
  # This factory produces new +resolv+ gem resolver instances. Users who wants
  # to configure a custom resolver (varying settings for varying resolvers) can
  # provide a custom resolver factory class and configure it globally on the
  # Excon defaults:
  #
  #   Excon.defaults[:resolver_factory] = MyCustomResolverFactory
  #
  # Then you just need to provide a static method called +.create_resolver+
  # which returns a new +Resolv+ instance. This allows the customization.
  class ResolverFactory
    # @return [Resolv] the new resolver instance
    def self.create_resolver
      Resolv.new
    end
  end
end
