require 'json'

module Restify
  #
  module Processors
    #
    # Decode plain JSON responses.
    #
    # JSON fields matching *_url will be parsed as relations.
    #
    class Json < Base

      def load
        parse ::JSON.load(body), root: true
      end

      private

      def parse(object, root: false)
        case object
          when Hash
            data      = object.each_with_object({}, &method(:parse_data))
            relations = object.each_with_object({}, &method(:parse_rels))

            if self.class.indifferent_access?
              data = with_indifferent_access(data)
            end

            if root
              Resource.new context, response: response, data: data, relations: relations
            else
              Resource.new context, data: data, relations: relations
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

        return if relations.key?(name) || pair[1].nil? || pair[1].to_s =~ /\A\w*\z/

        relations[name] = pair[1].to_s
      end

      def json
        @json ||= JSON.load response.body
      end

      def with_indifferent_access(data)
        Hashie::Mash.new data
      end

      class << self
        def accept?(response)
          response.content_type =~ /\Aapplication\/json($|;)/
        end

        def indifferent_access?
          @@indifferent_access
        end

        def indifferent_access=(value)
          @@indifferent_access = value
        end

        @@indifferent_access = true
      end
    end
  end
end
