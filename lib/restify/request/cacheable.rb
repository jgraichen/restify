require 'digest'

module Restify
  class Request
    #
    module Cacheable
      def cache_control
        @cache_control ||= Restify::Cache::CacheControl.new(@headers['Cache-Control'])
      end

      def cacheable?
        (method == :get || method == :head) && !cache_control.no_store?
      end

      def cache_key
        Digest::SHA256.hexdigest(uri.to_s)
      end
    end
  end
end
