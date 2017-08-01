# frozen_string_literal: true

module Restify
  module Global
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

    def cache
      @cache ||= begin
        require 'active_support/cache'
        Restify::Cache.new store: ActiveSupport::Cache::MemoryStore.new
      end
    end

    def cache=(cache)
      @cache = cache
    end

    def logger
      @logger ||= ::Logger.new(STDOUT).tap do |logger|
        logger.level = :info
      end
    end

    def logger=(logger)
      @logger = logger
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
