# frozen_string_literal: true

require 'delegate'

module Restify
  class Resource < SimpleDelegator
    # @api private
    #
    def initialize(context, response: nil, data: nil, relations: {}, error: nil)
      super(data)

      @context   = context
      @response  = response
      @relations = relations
      @error     = error
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

    # @api private
    def __getobj__
      # `Delegator` removes `Kernel#raise`, and the cause can only be
      # set when raising.
      ::Kernel.raise ParseError.new(@response, @error.message), cause: @error if @error

      super
    end

    # @!method data
    #
    #   Return response data. Usually a hash or array.
    #
    #   @return [Object] Response data.
    #   @raise [ParseError] If the response body could not be parsed.
    #
    alias data __getobj__

    # @api private
    def respond_to_missing?(name, include_private = false)
      return false if @error

      super
    end

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
        (@error ? '@error' : '@data') => @error || data,
        '@relations' => @relations,
      }.map {|k, v| "#{k}=#{v.inspect}" }.join(' ')

      "#<#{self.class} #{text}>"
    end
  end
end
