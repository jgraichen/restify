module Restify
  #
  class Resource < Hashie::Hash
    include Result
    include Relations
    include Hashie::Extensions::IndifferentAccess
    include Hashie::Extensions::MethodReader

    #
    def initialize(client, data = {}, response = nil)
      @client   = client
      @response = response

      relations.merge! @response.relations(client) if @response

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

        unless relations.key?(name) || value.nil? || value.to_s.empty?
          relations[name] = Relation.new(client, value.to_s)
        end
      end
    end

    # Compare with other {Resource}s or {Hash}s.
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
      case value
        when Hash
          self.new client, value
        else
          value
      end
    end
  end
end
