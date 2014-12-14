module Restify
  #
  class Relation
    def initialize(context, template)
      @context  = context
      @source   = template.to_s
      @template = Addressable::Template.new \
        context.uri.join(template.to_s).to_s
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
  end
end
