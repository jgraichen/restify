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

    def initialize(uri, opts = {})
      @uri  = uri.is_a?(Addressable::URI) ? uri : Addressable::URI.parse(uri.to_s)
      @opts = opts
    end

    def join(uri)
      self.uri.join uri
    end

    def request(method, uri, data = nil, opts = {})
      request = Request.new \
        method: method,
        uri: join(uri),
        data: data,
        headers: @opts.fetch(:headers, {})

      Restify.adapter.call(request).then do |response|
        Promise.create do |complete|
          complete.call response.success?, process(response), error(response)
        end
      end
    end

    private

    def process(response)
      context   = Context.new response.uri, @opts
      processor = Restify::PROCESSORS.find { |p| p.accept? response }
      processor ||= Restify::Processors::Base

      processor.new(context, response).resource
    end

    def error(response)
      self.class.response_error(response)
    end

    class << self
      def response_error(response)
        case response.code
          when 100...400
            nil
          when 400...500
            ClientError.new(response)
          when 500...600
            ServerError.new(response)
          else
            RuntimeError.new "Unknown response code: #{response.code}"
        end
      end
    end
  end
end
