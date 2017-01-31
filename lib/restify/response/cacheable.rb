require 'digest'

module Restify
  class Response
    #
    module Cacheable
      delegate :cache_key, to: :request

      CACHEABLE_STATUS_CODES = [200, 203, 300, 301, 302, 307, 404, 410].freeze

      def initialize(*)
        super

        @now = Time.now
      end

      def cache_control
        @cache_control ||= \
          Restify::Cache::CacheControl.new(headers['Cache-Control'])
      end

      def cacheable?
        return false unless date
        return false if cache_control.no_store?
        return false unless CACHEABLE_STATUS_CODES.include?(code)

        fresh?
      end

      def fresh?
        return false if cache_control.must_revalidate?
        return false if cache_control.no_cache?

        ttl & ttl > 0
      end

      def ttl
        0
      end
    end
  end
end
