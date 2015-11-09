require 'delegate'
require 'forwardable'

module Restify
  #
  class Resource < Delegator
    extend Forwardable

    # @api private
    #
    def initialize(context, response: nil, data: nil, relations: {})
      @data      = data
      @context   = context
      @response  = response
      @relations = relations
    end

    # @api private
    #
    def __getobj__
      @data
    end

    # Check if resource has a relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Boolean] True if resource has relation, false otherwise.
    #
    def relation?(name)
      @relations.key?(name) || @relations.key?(name.to_s)
    end

    alias_method :rel?, :relation?
    alias_method :has_rel?, :relation?
    alias_method :has_relation?, :relation?

    # Return relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Relation] Relation.
    #
    def relation(name)
      if @relations.key? name
        Relation.new @context, @relations.fetch(name)
      else
        Relation.new @context, @relations.fetch(name.to_s)
      end
    end

    alias_method :rel, :relation

    # @!method data
    #
    #   Return response data. Usually a hash or array.
    #
    #   @return [Object] Response data.
    #
    attr_reader :data

    # @!method response
    #
    #   Return response if available.
    #
    #   @return [Response] Response object.
    #   @see Context#response
    #
    attr_reader :response

    # Follow a LOCATION or CONTEXT-LOCATION header.
    #
    # @return [Relation] Relation to follow resource.
    # @raise RuntimeError If nothing to follow.
    #
    def follow
      if relation? :_restify_follow
        relation :_restify_follow
      else
        raise RuntimeError.new 'Nothing to follow'
      end
    end

    # @api private
    def _restify_relations
      @relations
    end

    # @api private
    def _restify_response=(response)
      @response = response
    end

    # @api private
    def inspect
      text = {
        "@data" => @data,
        "@relations" => @relations
      }.map {|k,v | k + '=' + v.inspect }.join(' ')

      "#<#{self.class} #{text}>"
    end
  end
end
