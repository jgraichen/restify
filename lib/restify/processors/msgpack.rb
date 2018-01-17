# frozen_string_literal: true

module Restify
  #
  module Processors
    #
    # Decode binary Msgpack responses.
    #
    # Fields matching *_url will be parsed as relations.
    #
    # This is intended to work as a drop-in performance
    # upgrade for the JSON processors. The two are 100%
    # compatible.
    #
    class Msgpack < Base
      def load
        parse ::MessagePack.unpack(body), root: true
      end

      private

      # rubocop:disable Metrics/MethodLength
      def parse(object, root: false)
        case object
          when Hash
            data      = object.each_with_object({}, &method(:parse_data))
            relations = object.each_with_object({}, &method(:parse_rels))

            if Processors::Json.indifferent_access?
              data = Hashie::Mash.new(data)
            end

            if root
              Resource.new context,
                data: data,
                response: response,
                relations: relations
            else
              Resource.new context,
                data: data,
                relations: relations
            end
          when Array
            object.map(&method(:parse))
          else
            object
        end
      end

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

        if relations.key?(name) || pair[1].nil? || pair[1].to_s =~ /\A\w*\z/
          return
        end

        relations[name] = pair[1].to_s
      end

      class << self
        def accept?(response)
          response.content_type =~ %r{\Aapplication/(x-)?msgpack($|;)}
        end
      end
    end
  end
end
