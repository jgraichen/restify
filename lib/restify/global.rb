# frozen_string_literal: true

module Restify
  module Global
    def new(uri, **)
      context = resolve_context(uri, **)

      Relation.new context, context.uri
    end

    def adapter
      @adapter ||= Restify::Adapter::Ethon.new
    end

    def adapter=(adapter)
      @adapter = adapter
    end

    # Cache for all requests, if any. Nothing is cached by default.
    #
    # @return [#call, nil] An object responding to
    #   `#call(request) { |request| promise }`, returning a promise of the
    #   response. The block performs the actual request.
    #
    attr_reader :cache

    def cache=(cache)
      @cache = cache
    end

    attr_reader :logger

    def logger=(logger)
      @logger = logger
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
