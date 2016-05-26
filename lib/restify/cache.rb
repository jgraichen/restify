module Restify
  class Cache
    def initialize(store)
      @store = store
    end

    def call(request)
      if (response = match(request))
        return response
      end

      yield(request).then do |response|
        cache(response)
        response
      end
    end

    private

    def match(request)
      false
    end

    def cache(response)
      # noop
    end
  end
end
