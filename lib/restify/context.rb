module Restify
  # A resource context.
  #
  # The resource context contains relations and the effective
  # response URI. The context is used to resolve relative URI
  # and follow links.
  #
  class Context
    include Addressable
    include Relations

    # The response object.
    #
    # @return [Response] The response or nil.
    #
    attr_reader :response

    # Effective context URI.
    #
    # @return [Addressable::URI] Effective context URI.
    #
    attr_reader :uri

    def initialize(uri, http, response = nil, _opts = {})
      @uri = uri.is_a?(URI) ? uri : URI.parse(uri.to_s)
      @http = http
      @response = response
    end

    def relations
      @relations ||= load_relations
    end

    def expand(uri)
      case uri
        when Addressable::Template
          Addressable::Template.new self.uri.join(uri.pattern).to_s
        else
          self.uri.join uri
      end
    end

    def follow
      if follow_location
        new_relation follow_location
      else
        raise RuntimeError.new 'Nothing to follow'
      end
    end

    def request(method, uri, data = nil, opts = {})
      request = @http.request(method, expand(uri), data, opts)
      request.then do |response|
        if response.success?
          inherit(uri: response.uri, response: response)
            .new_value(response.decoded_body)
        else
          Context.raise_response_error(response)
        end
      end
    end

    def inherit_value(value)
      inherit.new_value value
    end

    def new_relation(uri)
      Relation.new(self, uri.to_s, expand(uri))
    end

    def add_relation(name, uri)
      @relations[name] = new_relation(uri)
    end

    def inherit(opts = {})
      Context.new \
        opts.fetch(:uri) { @uri },
        opts.fetch(:http) { @http },
        opts.fetch(:response) { nil }
    end

    def new_value(value)
      case value
        when Hash
          Resource.new(self, value)
        when Array
          Collection.new(self, value)
        else
          value
      end
    end

    private

    def follow_location
      return unless @response

      @response.headers['LOCATION'] || @response.headers['CONTENT-LOCATION']
    end

    def load_relations
      response_links.each_with_object(Hashie::Mash.new) do |link, relations|
        if (rel = link.metadata['rel'])
          relations[rel] = new_relation link.uri
        end
      end
    end

    def response_links
      @response ? @response.links : []
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
