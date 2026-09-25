# frozen_string_literal: true

require 'rack/media_type'
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
    # The body is encoded according to the charset from the response's
    # `Content-Type` header. Without a charset, or with one unknown to
    # Ruby, the body is returned as binary.
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
      @body    = encode_body(body)
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

    # Return the encoding from the response's content type, if any.
    #
    # @return [Encoding, nil] Encoding, or nil if the content type
    #   carries no charset or an encoding unknown to Ruby.
    #
    def charset
      return @charset if defined?(@charset)

      charset = Rack::MediaType.params(content_type.to_s)['charset']

      @charset = begin
        Encoding.find(charset) if charset
      rescue ArgumentError
        # Unknown: keep the body as binary rather than guessing.
        nil
      end
    end

    # Check if response is successful e.g. the status code
    # is on of 2XX.
    #
    # @return [Boolean] True if status code is 2XX otherwise false.
    #
    def success?
      (200...300).cover? code
    end

    # Check if response is erroneous e.g. the status code
    # is one of 4XX or 5XX.
    #
    # @return [Boolean] True if status code is 2XX otherwise false.
    #
    def errored?
      (400...600).cover? code
    end

    # Decoded body for error messages, or nil if the body is empty or
    # could not be parsed.
    #
    # @api private
    def decoded_body
      return @decoded_body if defined?(@decoded_body)

      @decoded_body = begin
        case content_type
          when %r{\Aapplication/json($|;)}
            ::JSON.parse(body) unless body.nil? || body.empty?
        end
      rescue ::JSON::ParserError
        nil
      end
    end

    # @api private
    def follow_location
      headers['LOCATION'] || headers['CONTENT_LOCATION']
    end

    private

    def encode_body(body)
      return body unless body && charset

      (+body).force_encoding(charset)
    end

    def convert_headers(headers)
      headers.each.to_h do |pair|
        [pair[0].upcase, pair[1]]
      end
    end
  end
end
