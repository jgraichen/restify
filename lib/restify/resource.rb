# frozen_string_literal: true

require 'delegate'

module Restify
  class Resource < SimpleDelegator
    # @api private
    #
    def initialize(context, response: nil, data: nil, relations: {})
      super(data)

      @context   = context
      @response  = response
      @relations = relations
    end

    # Check if resource has a relation with given name.
    #
    # @param name [String, Symbol] Relation name.
    # @return [Boolean] True if resource has relation, false otherwise.
    #
    def relation?(name)
      @relations.key?(name) || @relations.key?(name.to_s)
    end

    alias rel? relation?
    alias has_rel? relation?
    alias has_relation? relation?

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

    alias rel relation

    # @!method data
    #
    #   Return response data. Usually a hash or array.
    #
    #   @return [Object] Response data.
    #
    alias data __getobj__

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
    # @return [Relation] Relation to follow resource or nil.
    #
    def follow
      relation :_restify_follow if relation? :_restify_follow
    end

    # Follow a LOCATION or CONTEXT-LOCATION header.
    #
    # @return [Relation] Relation to follow resource.
    # @raise RuntimeError If nothing to follow.
    #
    # rubocop:disable Style/GuardClause
    def follow!
      if (rel = follow)
        rel
      else
        raise 'Nothing to follow'
      end
    end
    # rubocop:enable all

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
        '@data' => data,
        '@relations' => @relations,
      }.map {|k, v| "#{k}=#{v.inspect}" }.join(' ')

      "#<#{self.class} #{text}>"
    end
  end
end
