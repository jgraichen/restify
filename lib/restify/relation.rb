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
      params    = convert params
      variables = extract! params

      uri = @template.expand variables
      uri.query_values = params if params.any?
      uri
    end

    private

    def request(method, data, params)
      @context.request method, expand(params), data
    end

    def convert(params)
      params.each_pair.each_with_object({}) do |param, hash|
        hash[param[0]] = convert_param param[1]
      end
    end

    def convert_param(value)
      return value.to_param.to_s if value.respond_to?(:to_param)
      value
    end

    def extract!(params)
      @template.variables.each_with_object({}) do |var, hash|
        if (value = params.delete(var) { params.delete(var.to_sym) { nil } })
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
