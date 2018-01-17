# frozen_string_literal: true

module Restify
  #
  # Parse JSON-compatible data structures (arrays, hashes, primitives...)
  # into Restify::Resource objects.
  #
  module ResourceParsing
    # rubocop:disable Metrics/MethodLength
    def parse(object, **resource_opts)
      case object
        when Hash
          data      = object.each_with_object({}, &method(:parse_data))
          relations = object.each_with_object({}, &method(:parse_rels))

          if Restify::Processors::Json.indifferent_access?
            data = Hashie::Mash.new(data)
          end

          Resource.new self,
            data: data,
            relations: relations,
            **resource_opts
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
  end
end
