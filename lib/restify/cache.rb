module Restify
  class Cache
    require 'restify/cache/cache_control'

    delegate :clear, to: :@store

    def initialize(store:)
      @store = store
    end

    def call(request)
      if (response = read(request))
        return Promise.fulfilled(response)
      end

      yield(request).then do |response|
        write(response)
        response
      end
    end

    private

    def read(request)
      return unless request.cacheable?

      cached = store.read(request.cache_key)
      return unless cached

      cached
    end

    def write(response)
      prepare(response)

      puts "#{response.cacheable?}, #{response.cache_control}"

      return unless response.cacheable?

      store.write(response.cache_key, response)
    end

    private

    attr_reader :store

    def prepare(response)
      response.headers['DATE'] ||= Time.now.httpdate
    end
  end
end
