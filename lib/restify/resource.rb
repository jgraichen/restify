module Restify
  #
  class Resource
    include Relations

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
    delegate :[], to: :attributes

    # @!method key?(name)
    #   Check if resource has given key.
    #
    #   @param name [String, Symbol] Key name.
    #   @return [Boolean] True if resource contains key, false otherwise.
    #
    delegate :key?, :has_key?, to: :attributes

    # @!method each
    #   Iterate over keys and values or return enumerator.
    #
    #   @overload each
    #     Calls block once for each key, passing the key-value pair as
    #     parameters.
    #
    #     @yield [key, value] Yield for each key-value pair.
    #     @yieldparam key [String] Attribute key.
    #     @yieldparam value [Object] Attribute value.
    #
    #   @overload each
    #     Return enumerator for each key-value pair.
    #
    #     @return [Enumerator] Enumerator for each key-value pair.
    #
    delegate :each, to: :attributes

    # Return parsed resource attributes as hash.
    #
    # @return [HashWithIndifferentAccess] Attribute hash.
    #
    def attributes
      @attributes ||= HashWithIndifferentAccess.new
    end

    private

    def initialize(client)
      @client = client
    end

    class << self
      #
      # Build a resource from given response.
      #
      def create(client, data, response)
        new(client).tap do |res|
          res.relations.merge! response.relations(client) if response

          if data
            res.attributes.merge! data
            data.keys.each do |key|
              name = nil
              if (m = /\A(\w+)_url\z/.match(key))
                name = m[1]
              elsif key == 'url'
                name = :self
              else
                next
              end

              unless res.rel?(name)
                res.relations[name] = Relation.new(client, data[key])
              end
            end
          end
        end
      end
    end
  end
end
