# frozen_string_literal: true

require 'json'

module Restify
  module Processors
    class Base
      #
      # Parses generic data structures into resources
      #
      module Parsing
        RELATION_NAME = /\A\w+_url\z/i

        def load
          # No data, e.g. when a server sets a content type but sends an
          # empty body.
          return if body.nil? || body.empty?

          begin
            data = deserialized_body
          rescue StandardError => e
            # Keep the resource, e.g. with relations from headers, but
            # raise on accessing its data.
            return Resource.new(context, response:, error: e)
          end

          parse(data, root: true)
        end

        def parse(object, root: false)
          case object
            when Hash then build_resource(object, root)
            when Array then object.map {|each| parse(each) }
            else object
          end
        end

        private

        # Build data and relations of a resource in one pass.
        def build_resource(object, root)
          data = {}
          relations = {}

          object.each_pair do |key, value|
            key = key.to_s
            data[key] = parse(value)
            parse_relation(relations, key, value) if value.is_a?(String)
          end

          Resource.new(
            context,
            data:,
            response: root ? response : nil,
            relations:,
          )
        end

        def parse_relation(relations, key, value)
          name = if key.match?(RELATION_NAME)
                   key[0, key.length - 4].downcase
                 elsif key.casecmp?('url')
                   'self'
                 end

          return if name.nil? || relations.key?(name)
          return if value.empty?

          relations[name] = value
        end
      end
    end
  end
end
