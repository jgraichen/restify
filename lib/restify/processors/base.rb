# frozen_string_literal: true
module Restify
  #
  module Processors
    #
    class Base
      extend Forwardable

      #
      attr_reader :context

      #
      attr_reader :response

      def initialize(context, response)
        @context  = context
        @response = response
      end

      def resource
        @resource ||= begin
          resource = load

          unless resource.is_a? Restify::Resource
            resource = Resource.new context, response: response, data: resource
          end

          resource._restify_response = response
          merge_relations! resource._restify_relations

          resource
        end
      end

      # Return resource or data.
      #
      # Should be overridden in subclass.
      #
      def load; end

      # @!method body
      #
      delegate body: :@response

      private

      def merge_relations!(relations)
        response.links.each do |link|
          name  = link.metadata['rel']
          value = link.uri

          relations[name] = value if !name.empty? && !relations.key?(name)
        end

        location = @response.follow_location
        return unless location

        relations[:_restify_follow] = location
      end

      class << self
        def accept?(_response)
          false
        end
      end
    end
  end
end
