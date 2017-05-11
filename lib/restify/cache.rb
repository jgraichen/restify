# frozen_string_literal: true

module Restify
  class Cache
    def initialize(store)
      @store = store
    end

    def call(request)
      if (response = match(request))
        return response
      end

      yield(request).then do |new_response|
        cache(new_response)
        new_response
      end
    end

    private

    def match(_request)
      false
    end

    def cache(response)
      # noop
    end
  end
end
