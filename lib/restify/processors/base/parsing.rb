# frozen_string_literal: true

require 'json'

module Restify
  module Processors
    class Base
      #
      # Parses generic data structures into resources
      #
      module Parsing
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
            when Hash
              data      = object.each_with_object({}) {|each, obj| parse_data(each, obj) }
              relations = object.each_with_object({}) {|each, obj| parse_rels(each, obj) }

              Resource.new context,
                data:,
                response: root ? response : nil,
                relations:

            when Array
              object.map {|each| parse(each) }
            else
              object
          end
        end

        private

        def parse_data(pair, data)
          data[pair[0].to_s] = parse pair[1]
        end

        def parse_rels(pair, relations)
          name = case pair[0].to_s.downcase
                   when /\A(\w+)_url\z/
                     Regexp.last_match[1]
                   when 'url'
                     'self'
                   else
                     return
                 end

          return if relations.key?(name) || pair[1].nil? || pair[1].to_s =~ /\A\w*\z/

          relations[name] = pair[1].to_s
        end
      end
    end
  end
end
