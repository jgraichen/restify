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

    def expand(params)
      @template.expand extracted params
    end

    private

    def request(method, data, params)
      @context.request method, expand(params), data
    end

    def extracted(params)
      @template.variables.each_with_object({}) do |var, hash|
        if (value = params.delete(var) { params.delete(var.to_sym) { nil } })
          value = value.to_param if value.respond_to?(:to_param)
          hash[var] = value
        end
      end
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
