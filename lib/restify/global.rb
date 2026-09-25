# frozen_string_literal: true

module Restify
  module Global
    def new(uri, **)
      context = resolve_context(uri, **)

      Relation.new context, context.uri
    end

    attr_writer :adapter
    attr_accessor :cache, :logger

    def adapter
      @adapter ||= Restify::Adapter::Ethon.new
    end

    private

    def resolve_context(uri, **)
      if uri.is_a? Symbol
        Restify::Registry.fetch(uri).inherit(nil, **)
      else
        Context.new(uri, **)
      end
    end
  end
end
