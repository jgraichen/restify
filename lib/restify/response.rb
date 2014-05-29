require 'rack/utils'

module Restify
  #
  # A {Response} is returned from an {Adapter} and described
  # a HTTP response. That includes status code, headers and
  # body.
  #
  # A {Response} is also responsible for decoding its body
  # according its content type.
  #
  class Response
    #
    # Map of status symbols to codes. From Rack::Utils.
    #
    # @example
    #   SYMBOL_TO_STATUS_CODE[:ok] #=> 200
    #
    SYMBOL_TO_STATUS_CODE = Rack::Utils::SYMBOL_TO_STATUS_CODE

    # Map of status codes to symbols.
    #
    # @example
    #   STATUS_CODE_TO_SYMBOL[200] #=> :ok
    #
    STATUS_CODE_TO_SYMBOL = SYMBOL_TO_STATUS_CODE.invert

    # Response body as string.
    #
    # @return [String] Response body.
    #
    attr_reader :body

    # Response headers as hash.
    #
    # @return [Hash<String, String>] Response headers.
    #
    attr_reader :headers

    # Response status code.
    #
    # @return [Fixnum] Status code.
    #
    attr_reader :code

    # Response status symbol.
    #
    # @example
    #   response.status #=> :ok
    #
    # @return [Symbol] Status symbol.
    #
    attr_reader :status

    # Response status message.
    #
    # @return [String] Status message.
    #
    attr_reader :message

    # The request that led to this response.
    #
    # @return [Request] Request object.
    #
    attr_reader :request

    # @api private
    #
    def initialize(request, code, headers, body)
      @request = request
      @code    = code
      @status  = STATUS_CODE_TO_SYMBOL[code]
      @headers = headers
      @body    = body
      @message = Rack::Utils::HTTP_STATUS_CODES[code]
    end

    # Return URL of this response.
    #
    def url
      request.uri
    end

    # Return list of links from the Link header.
    #
    # @return [Array<Link>] Links.
    #
    def links
      @links ||= begin
        if headers['Link']
          begin
            Link.parse(headers['Link'])
          rescue ArgumentError => e
            warn e
            []
          end
        else
          []
        end
      end
    end

    # Return list of relations extracted from links.
    #
    # @return [Array<Relation>] Relations.
    #
    def relations(client)
      relations = {}
      links.each do |link|
        if (rel = link.metadata['rel'])
          relations[rel] = Relation.new(client, link.uri)
        end
      end
      relations
    end

    # Return decoded body according to content type.
    # Will return `nil` if content cannot be decoded.
    #
    # @return [Array, Hash, NilClass] Decoded response body.
    #
    def decoded_body
      @decoded_body ||= begin
        case headers['Content-Type']
        when /\Aapplication\/json($|;)/
          MultiJson.load body
        else
          nil
        end
      end
    end

    # Check if response is successful e.g. the status code
    # is on of 2XX.
    #
    # @return [Boolean] True if status code is 2XX otherwise false.
    #
    def success?
      (200...300) === code
    end
  end
end
