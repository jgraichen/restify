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
      @template = Addressable::Template.new(template)
    end

    def request(method:, params: {}, **opts)
      context.request(method, expand(params), **opts)
    end

    def get(data = {}, params: {}, **opts)
      request(**opts, method: :get, params: data.merge(params))
    end

    def head(data = {}, params: {}, **opts)
      request(**opts, method: :head, params: data.merge(params))
    end

    def delete(data = {}, params: {}, **opts)
      request(**opts, method: :delete, params: data.merge(params))
    end

    def post(data = nil, **opts)
      opts[:data] = data unless opts.key?(:data)
      request(**opts, method: :post)
    end

    def put(data = nil, **opts)
      opts[:data] = data unless opts.key?(:data)
      request(**opts, method: :put)
    end

    def patch(data = nil, **opts)
      opts[:data] = data unless opts.key?(:data)
      request(**opts, method: :patch)
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
      params.each_pair.with_object({}) do |param, hash|
        hash[param[0]] = convert_param param[1]
      end
    end

    def convert_param(value, nesting: true)
      # Convert parameters into values acceptable in a
      # Addressable::Template, with some support for #to_param, but not
      # for basic types.
      if value == nil || # rubocop:disable Style/NilComparison
         value.is_a?(Numeric) ||
         value.is_a?(Symbol) ||
         value.is_a?(Hash) ||
         value == true ||
         value == false ||
         value.respond_to?(:to_str)
        return value
      end

      # Handle array-link things first to *not* call #to_params on them,
      # as that will concatenation any Array to "a/b/c". Instead, we
      # want to check one level of basic types only.
      if value.respond_to?(:to_ary)
        return nesting ? value.to_ary.map {|val| convert_param(val, nesting: false) } : value
      end

      # Handle Rails' #to_param for non-basic types
      if value.respond_to?(:to_param)
        return value.to_param
      end

      # Otherwise, pass raw value to Addressable::Template and let it
      # explode.
      value
    end

    def extract!(params)
      @template.variables.each_with_object({}) do |var, hash|
        sym = var.to_sym
        if params.key?(var)
          hash[var] = params.delete(var)
        end
        if params.key?(sym)
          hash[sym] = params.delete(sym)
        end
      end
    end
  end
end
