module Restify
  class Cache
    class CacheControl
      delegate :[], :key?, to: :@directives

      def initialize(str = nil, **kwargs)
        @directives = {
          'public': kwargs.fetch(:public, false),
          'private': kwargs.fetch(:private, false),
          'no-cache': kwargs.fetch(:no_cache, false),
          'no-store': kwargs.fetch(:no_store, false),
          'no-transform': kwargs.fetch(:no_transform, false),
          'only-if-cached': kwargs.fetch(:only_if_cached, false),
          'must-revalidate': kwargs.fetch(:must_revalidate, false),
          'proxy-revalidate': kwargs.fetch(:proxy_revalidate, false),
          'max-age': Integer(kwargs.fetch(:max_age, 0)),
          's-maxage': Integer(kwargs.fetch(:s_maxage, 0)),
          'max-stale': Integer(kwargs.fetch(:max_stale, 0)),
          'min-fresh': Integer(kwargs.fetch(:min_fresh, 0))
        }

        @directive.merge! kwargs[:directives] if kwargs.key?(:directives)

        parse!(str) if str
      end

      def public?
        self['public']
      end

      def private?
        self['private']
      end

      def no_cache?
        self['no-cache']
      end

      def no_store?
        self['no-store']
      end

      def no_transform?
        self['no-transform']
      end

      def only_if_cached?
        self['only-if-cached']
      end

      def must_revalidate?
        self['must-revalidate']
      end

      def proxy_revalidate?
        self['proxy-revalidate']
      end

      def max_age
        self['max-age']
      end

      def s_maxage
        self['s-maxage']
      end

      def max_stale
        self['max-stale']
      end

      def min_fresh
        self['min-fresh']
      end

      def to_s
        @directives.each_pair.map do |name, value|
          next unless value && value != 0
          value === true ? "#{name}" : "#{name}=#{value}"
        end.reject(&:nil?).join(', ')
      end

      private

      def parse!(str)
        str.trim().split(/\s+,\s+/).each do |directive|
          key, value = directive.split('=', 1)

          if value.nil?
            value = true
          elsif value =~ /\A[0-9]+\z/
            value = value.to_i
          end

          @directives[key.downcase] = value
        end
      end
    end
  end
end
