require 'rack/utils'
require 'json'

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

    # Last effective URI.
    #
    # @return [Addressable::URI] Last effective URI.
    #
    attr_reader :uri

    # @api private
    #
    def initialize(request, uri, code, headers, body)
      @request = request
      @uri     = uri
      @code    = code
      @status  = STATUS_CODE_TO_SYMBOL[code]
      @headers = convert_headers(headers)
      @body    = body
      @message = Rack::Utils::HTTP_STATUS_CODES[code]
    end

    # Return list of links from the Link header.
    #
    # @return [Array<Link>] Links.
    #
    def links
      @links ||= begin
        if headers['LINK']
          begin
            Link.parse(headers['LINK'])
          rescue ArgumentError => e
            warn e
            []
          end
        else
          []
        end
      end
    end

    # Return content type header from response headers.
    #
    # @return [String] Content type header.
    #
    def content_type
      headers['CONTENT_TYPE']
    end

    # Check if response is successful e.g. the status code
    # is on of 2XX.
    #
    # @return [Boolean] True if status code is 2XX otherwise false.
    #
    def success?
      (200...300).include? code
    end

    # @api private
    def decoded_body
      @decoded_body ||= begin
        case content_type
          when /\Aapplication\/json($|;)/
            JSON.load body
        end
      end
    end

    # @api private
    def follow_location
      headers['LOCATION'] || headers['CONENT_LOCATION']
    end

    private

    def convert_headers(headers)
      headers.each_with_object({}) do |pair, hash|
        hash[pair[0].upcase] = pair[1]
      end
    end
  end
end
