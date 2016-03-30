module Restify
  module Global
    extend self

    def new(uri, **opts)
      context = resolve_context uri, **opts

      Relation.new context, context.uri
    end

    def adapter
      @adapter ||= begin
        require 'restify/adapter/em'
        Restify::Adapter::EM.new
      end
    end

    def adapter=(adapter)
      @adapter = adapter
    end

    private

    def resolve_context(uri, **opts)
      if uri.is_a? Symbol
        Restify::Registry.fetch(uri).inherit(nil, opts)
      else
        Context.new uri, opts
      end
    end
  end
end
