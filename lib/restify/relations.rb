module Restify
  #
  module Relations
    #
    # Check if resource has a relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Boolean] True if resource has relation, false otherwise.
    #
    def rel?(name)
      relations.key? name.to_s
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
      relations.fetch name.to_s
    end
    alias_method :relation, :rel

    # Hash of all known relations.
    #
    # @return [Hash<String, Relation>] Relations.
    #
    def relations
      @relations ||= Hash.new
    end
  end
end
