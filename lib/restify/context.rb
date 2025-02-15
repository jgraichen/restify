# frozen_string_literal: true

module Restify
  # A resource context.
  #
  # The resource context contains relations and the effective
  # response URI. The context is used to resolve relative URI
  # and follow links.
  #
  class Context
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
      uri ||= self.uri
      Context.new(uri, **kwargs, **options)
    end

    def process(response)
      context   = inherit response.uri
      processor = Restify::PROCESSORS.find {|p| p.accept? response }
      processor ||= Restify::Processors::Base

      processor.new(context, response).resource
    end

    def request(method, uri, data: nil, headers: {}, **kwargs)
      request = Request.new(
        headers: default_headers.merge(headers),
        **kwargs,
        method:,
        uri: join(uri),
        data:,
      )

      ret = cache.call(request) {|req| adapter.call(req) }
      ret.then do |response|
        raise ResponseError.from_code(response) if response.errored?

        process(response)
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
        headers: default_headers,
      }
    end

    def marshal_load(dump)
      initialize dump.delete(:uri),
        headers: dump.fetch(:headers)
    end

    private

    def adapter
      options[:adapter] || Restify.adapter
    end

    def cache
      options[:cache] || Restify.cache
    end

    def default_headers
      options.fetch(:headers, {})
    end
  end
end
