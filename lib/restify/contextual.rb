module Restify
  module Contextual
    extend Forwardable

    # @!method relations
    #
    #   Return hash of all relations.
    #
    #   @return [Hashie::Mash] Relations.
    #   @see Context#relations
    #
    delegate :relations => :@context

    # @!method response
    #
    #   Return response if available.
    #
    #   @return [Response] Response object.
    #   @see Context#response
    #
    delegate :response => :@context

    # @!method follow
    #
    #   Follow a LOCATION or CONTEXT-LOCATION header.
    #
    #   @return [Relation] Relation to follow resource.
    #   @see Context#follow
    #
    delegate :follow => :@context
  end
end
