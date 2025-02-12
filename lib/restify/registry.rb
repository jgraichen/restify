# frozen_string_literal: true

module Restify
  class Registry
    def initialize
      @registry = {}
    end

    def store(name, uri, **opts)
      @registry[name] = Context.new(uri, **opts)
    end

    def fetch(name)
      @registry.fetch name
    end

    class << self
      extend Forwardable

      def instance
        @instance ||= new
      end

      delegate store: :instance
      delegate fetch: :instance
    end
  end
end
