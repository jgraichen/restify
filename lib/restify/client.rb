module Restify
  #
  # A {ResponseError} is returned on a non-successful
  # response from server. Usually it will either be a
  # {ClientError} or a {ServerError}.
  #
  class ResponseError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super "#{response.message} (#{response.code}) for `#{response.url}':\n" \
            "  #{errors.inspect}"
    end

    # Return response status.
    #
    # @return [Symbol] Response status.
    # @see Response#status
    #
    def status
      response.status
    end

    # Return response status code.
    #
    # @return [Fixnum] Response status code.
    # @see Response#code
    #
    def code
      response.code
    end

    # Return hash or array of errors if response included
    # such a thing otherwise it returns nil.
    #
    def errors
      response.decoded_body['errors'] || response.decoded_body[:errors]
    end
  end

  # A {ClientError} will be raised when a response has a
  # 4XX status code.
  class ClientError < ResponseError; end

  # A {ServerError} will be raised when a response has a
  # 5XX status code.
  class ServerError < ResponseError; end

  # @api private
  #
  class Client
    #
    # Keys that should not be extracted from options
    # to expand URI templates.
    RESERVED_KEYS = [:data]

    # @api private
    #
    # Request given path with given method.
    #
    # Returns an obligation that will return a collection or
    # resource or fail with a response error depending on
    # response from server.
    #
    def request(method, path, opts = {})
      data    = opts.fetch(:data, opts)
      request = Request.new method: method, uri: base.join(path.to_s), data: data

      ::Restify.adapter.call(request).then do |response|
        if response.success?
          handle_success response
        else
          handle_error response
        end
      end
    end

    private

    attr_reader :base

    def initialize(uri)
      @base = ::Addressable::URI.parse(uri)
    end

    def handle_success(response)
      if response.decoded_body.is_a?(Array)
        Collection.create(self, response.decoded_body, response)
      else
        Resource.create(self, response.decoded_body, response)
      end
    end

    def handle_error(response)
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
