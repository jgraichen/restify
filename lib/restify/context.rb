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

    def initialize(uri)
      @uri  = uri.is_a?(Addressable::URI) ? uri : Addressable::URI.parse(uri.to_s)
    end

    def join(uri)
      self.uri.join uri
    end

    def process(response)
      context   = Context.new response.uri
      processor = Restify::PROCESSORS.find { |p| p.accept? response }
      processor ||= Restify::Processors::Base

      processor.new(context, response).resource
    end

    def request(method, uri, data = nil, opts = {})
      request = Request.new method: method, uri: join(uri), data: data

      Restify.adapter.call(request).then do |response|
        if response.success?
          process response
        else
          Context.raise_response_error(response)
        end
      end
    end

    class << self
      def raise_response_error(response)
        case response.code
          when 400...500
            raise ClientError.new(response)
          when 500...600
            raise ServerError.new(response)
          else
            raise RuntimeError.new "Unknown response code: #{response.code}"
        end
      end
    end
  end
end
