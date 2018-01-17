# frozen_string_literal: true

require 'restify/resource_parsing'

module Restify
  # A resource context.
  #
  # The resource context contains relations and the effective
  # response URI. The context is used to resolve relative URI
  # and follow links.
  #
  class Context
    include ResourceParsing

    # Effective context URI.
    #
    # @return [Addressable::URI] Effective context URI.
    #
    attr_reader :uri

    # Options passed to this context.
    #
    # @return [Hash] Options.
    #
    attr_reader :options

    def initialize(uri, **kwargs)
      @uri = if uri.is_a?(Addressable::URI)
               uri
             else
               @uri = Addressable::URI.parse(uri.to_s)
             end

      @options = kwargs
    end

    def join(uri)
      self.uri.join uri
    end

    def inherit(uri, **kwargs)
      uri = self.uri unless uri
      Context.new uri, kwargs.merge(options)
    end

    def process(response)
      context   = inherit response.uri
      processor = Restify::PROCESSORS.find {|p| p.accept? response }
      processor ||= Restify::Processors::Base

      processor.new(context, response).resource
    end

    # rubocop:disable Metrics/MethodLength
    def request(method, uri, data: nil, **kwargs)
      request = Request.new(**kwargs,
        method: method,
        uri: join(uri),
        data: data,
        headers: headers
      )

      ret = cache.call(request) {|req| adapter.call(req) }
      ret.then do |response|
        if response.success?
          process response
        else
          Context.raise_response_error(response)
        end
      end
    end

    def encode_with(coder)
      coder.map = marshal_dump
    end

    def init_with(coder)
      marshal_load(coder.map)
    end

    def marshal_dump
      {
        uri: uri.to_s,
        headers: headers
      }
    end

    def marshal_load(dump)
      initialize dump.delete(:uri), \
        headers: dump.fetch(:headers)
    end

    private

    def adapter
      options[:adapter] || Restify.adapter
    end

    def cache
      options[:cache] || Restify.cache
    end

    def headers
      options.fetch(:headers, {})
    end

    class << self
      def raise_response_error(response)
        case response.code
          when 400...500
            raise ClientError.new(response)
          when 500...600
            raise ServerError.new(response)
          else
            raise "Unknown response code: #{response.code}"
        end
      end
    end
  end
end
