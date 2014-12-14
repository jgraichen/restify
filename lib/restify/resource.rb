module Restify
  #
  class Resource < Hashie::Hash
    include Contextual
    include Relations
    include Hashie::Extensions::IndifferentAccess
    include Hashie::Extensions::MethodReader

    #
    def initialize(context, data = {})
      @context = context

      data.each_pair do |key, value|
        self[key.to_s] = convert_value(value)

        name = case key.to_s.downcase
          when /\A(\w+)_url\z/
            $1
          when 'url'
            'self'
          else
            next
        end

        unless @context.relation?(name) || value.nil? || value.to_s.empty?
          @context.add_relation name, value.to_s
        end
      end
    end

    # Compare with other {Resource}s or hashes.
    #
    def ==(other)
      case other
        when Resource
          super && relations == other.relations
        when Hash
          super Hash[other.map{|k,v| [convert_key(k), v] }]
        else
          super
      end
    end

    # @private
    #
    def convert_key(key)
      key.to_s
    end

    # @private
    #
    def convert_value(value)
      @context.inherit_value(value)
    end
  end
end
