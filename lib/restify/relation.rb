# frozen_string_literal: true

module Restify
  class Relation
    # Relation context
    #
    # @return [Restify::Context] Context
    #
    attr_reader :context

    # Relation URI template
    #
    # @return [Addressable::Template] URI template
    #
    attr_reader :template

    def initialize(context, template)
      @context  = context
      @template = Addressable::Template.new template
    end

    def request(method, data, params, opts = {})
      context.request method, expand(params), **opts, data: data
    end

    def get(params = {}, opts = {})
      request :get, nil, params, opts
    end

    def head(params = {}, opts = {})
      request :head, nil, params, opts
    end

    def delete(params = {}, opts = {})
      request :delete, nil, params, opts
    end

    def post(data = {}, params = {}, opts = {})
      request :post, data, params, opts
    end

    def put(data = {}, params = {}, opts = {})
      request :put, data, params, opts
    end

    def patch(data = {}, params = {}, opts = {})
      request :patch, data, params, opts
    end

    def ==(other)
      super || (other.is_a?(String) && template.pattern == other)
    end

    def expand(params)
      params    = convert params
      variables = extract! params

      uri = template.expand variables
      uri.query_values = (uri.query_values || {}).merge params if params.any?

      context.join uri
    end

    def pattern
      template.pattern
    end

    def to_s
      pattern
    end

    private

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
