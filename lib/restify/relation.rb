module Restify
  #
  class Relation
    def initialize(context, source, pattern)
      @context  = context
      @source   = source
      @template = to_template(pattern)
    end

    def get(params = {})
      request :get, nil, params
    end

    def delete(params = {})
      request :delete, nil, params
    end

    def post(data = {}, params = {})
      request :post, data, params
    end

    def put(data = {}, params = {})
      request :put, data, params
    end

    def patch(data = {}, params = {})
      request :patch, data, params
    end

    def ==(other)
      super ||
        (other.is_a?(String) && @template.pattern == other) ||
        (other.is_a?(String) && @source == other)
    end

    private

    attr_reader :client, :template

    def request(method, data, params)
      uri = template.expand params

      @context.request method, uri, data
    end

    def to_template(pattern)
      if pattern.is_a?(Addressable::Template)
        pattern
      else
        Addressable::Template.new pattern
      end
    end
  end
end
