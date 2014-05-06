require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/module/delegation'

module Restify
  #
  class Resource
    #
    # Check if resource has a relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Boolean] True if resource has relation, false otherwise.
    #
    def rel?(name)
      relations.key? name
    end
    alias_method :relation?, :rel?
    alias_method :has_rel?, :rel?
    alias_method :has_relation?, :rel?

    # Return relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Relation] Relation.
    #
    def rel(name)
      relations.fetch name
    end
    alias_method :relation, :rel

    # Hash of all known relations.
    #
    # @return [HashWithIndifferentAccess<String, Relation>] Relations.
    #
    def relations
      @relations ||= HashWithIndifferentAccess.new
    end

    # Return content Media-Type.
    #
    # @return [MediaType] Resource media type.
    #
    attr_reader :media_type

    # @!method [](key)
    #   Retrieve value for given key.
    #
    #   @param key [String, Symbol] Data key.
    #   @return [Object] Data value for given key.
    #
    delegate :[], to: :data

    # @!method key?(name)
    #   Check if resource has given key.
    #
    #   @param name [String, Symbol] Key name.
    #   @return [Boolean] True if resource contains key, false otherwise.
    #
    delegate :key?, :has_key?, to: :data

    # @!method each
    #   Iterate over keys and values or return enumerator.
    #
    #   @overload each
    #     Calls block once for each key, passing the key-value pair as
    #     parameters.
    #
    #     @yield [key, value] Yield for each key-value pair.
    #     @yieldparam key [String] Data key.
    #     @yieldparam value [Object] Data value.
    #
    #   @overload each
    #     Return enumerator for each key-value pair.
    #
    #     @return [Enumerator] Enumerator for each key-value pair.
    #
    delegate :each, to: :data

    # Return parsed resource data as hash.
    #
    # @return [HashWithIndifferentAccess] Data hash.
    #
    def data
      @data ||= HashWithIndifferentAccess.new
    end

    class << self
      #
      # Build a resource from given response.
      #
      def build(data, response)
        new.tap do |res|
          if response
            response.links.map do |key, uri|
              res.relations[key] = Relation.new(uri) if Relation.valid?(uri)
            end
          end

          if data
            res.data.merge data
            data.keys.each do |key|
              name = nil
              if (m = /\A(\w+)_url\z/.mathc(key))
                name = m[1]
              elsif key == 'url'
                name = :self
              else
                next
              end

              if Relation.valid?(data[key]) && !res.rel?(name)
                res.relations[name] = Relation.new(data[key])
              end
            end
          end
        end
      end
    end
  end
end
