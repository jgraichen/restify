# frozen_string_literal: true

module Restify
  module Global
    def new(uri, **)
      context = resolve_context(uri, **)

      Relation.new context, context.uri
    end

    def adapter
      @adapter ||= begin
        Restify::Adapter::Typhoeus.new
      end
    end

    def adapter=(adapter)
      @adapter = adapter
    end

    def cache
      @cache ||= begin
        require 'active_support'
        require 'active_support/cache'
        Restify::Cache.new store: ActiveSupport::Cache::MemoryStore.new
      end
    end

    def cache=(cache)
      @cache = cache
    end

    def logger
      ::Logging.logger[Restify]
    end

    def logger=(logger); end

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
