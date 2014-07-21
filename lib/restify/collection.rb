module Restify
  #
  class Collection
    include Relations

    # @!method [](index)
    #   Retrieve value for given index.
    #
    #   @param index [Integer] Index.
    #   @return [Object] Data value for given index.
    #
    delegate :[], to: :items

    # @!method size
    #   Return size of collection. Only includes size of current
    #   page in paginated resources.
    #
    #   @return [Integer] Number of items in current collection.
    #
    delegate :size, to: :items

    # @!method first
    #   Return first item of collection.
    #
    #   @return [Resource, Collection, Object] Return first
    #
    delegate :first, to: :items

    # @!method each
    #   Iterate over all items or return enumerator.
    #
    #   @overload each
    #     Calls block once for each item, passing the item as
    #     parameters.
    #
    #     @yield [item] Yield for each item.
    #     @yieldparam item [Resource, Collection, Object] Collection item.
    #
    #   @overload each
    #     Return enumerator for each item.
    #
    #     @return [Enumerator] Enumerator for each item.
    #
    delegate :each, to: :items

    # Return parsed resource attributes as hash.
    #
    # @return [Array] Collection items.
    #
    def items
      @items ||= []
    end

    def initialize(client, relations = {}, items = [])
      @client     = client
      @relations  = HashWithIndifferentAccess.new relations
      @items      = Array items
    end

    class << self
      def create(client, data, response)
        data = data.map do |value|
          case value
            when Hash
              Resource.create client, value, nil
            when Array
              create client, value, nil
            else
              value
          end
        end

        relations = response ? response.relations(client) : nil

        new client, relations, data
      end
    end
  end
end
