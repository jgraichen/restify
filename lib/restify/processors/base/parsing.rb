# frozen_string_literal: true

require 'json'

module Restify
  module Processors
    class Base
      #
      # Parses generic data structures into resources
      #
      module Parsing
        def self.included(base)
          base.extend ClassMethods
          base.indifferent_access = true
        end

        def load
          parse deserialized_body, root: true
        end

        def parse(object, root: false)
          case object
            when Hash
              data      = object.each_with_object({}) {|each, obj| parse_data(each, obj) }
              relations = object.each_with_object({}) {|each, obj| parse_rels(each, obj) }

              data = with_indifferent_access(data) if self.class.indifferent_access?

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

        def with_indifferent_access(data)
          Hashie::Mash.new data
        end

        module ClassMethods
          def indifferent_access?
            @indifferent_access
          end

          attr_writer :indifferent_access
        end
      end
    end
  end
end
