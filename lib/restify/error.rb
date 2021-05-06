# frozen_string_literal: true

module Restify
  # A {NetworkError} is raised on unusual network exceptions such as
  # unresolvable hosts or disconnects.
  #
  class NetworkError < StandardError
    attr_reader :request

    def initialize(request, message)
      @request = request
      super("[#{request.uri}] #{message}")
    end
  end

  # A {ResponseError} is returned on a non-successful
  # response from server. Usually it will either be a
  # {ClientError} or a {ServerError}.
  #
  class ResponseError < StandardError
    attr_reader :response

    def self.from_code(response)
      case response.code
        when 400
          BadRequest.new(response)
        when 401
          Unauthorized.new(response)
        when 404
          NotFound.new(response)
        when 406
          NotAcceptable.new(response)
        when 410
          Gone.new(response)
        when 422
          UnprocessableEntity.new(response)
        when 429
          TooManyRequests.new(response)
        when 400...500
          ClientError.new(response)
        when 500
          InternalServerError.new(response)
        when 502
          BadGateway.new(response)
        when 503
          ServiceUnavailable.new(response)
        when 504
          GatewayTimeout.new(response)
        when 500...600
          ServerError.new(response)
        else
          raise "Unknown response code: #{response.code}"
      end
    end

    def initialize(response)
      @response = response
      super "#{response.message} (#{response.code}) for `#{response.uri}':\n" \
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
      if response.decoded_body
        response.decoded_body['errors'] ||
          response.decoded_body[:errors] ||
          response.decoded_body
      else
        response.body
      end
    end
  end

  # A {ClientError} will be raised when a response has a
  # 4XX status code.
  class ClientError < ResponseError; end

  # A {ServerError} will be raised when a response has a
  # 5XX status code.
  class ServerError < ResponseError; end

  # A {GatewayError} is the common base class for 502, 503 and 504
  # response codes often used by load balancers when upstream servers are
  # failing or not available.
  #
  # This can be used to catch "common" gateway responses.
  class GatewayError < ServerError; end

  ###
  # CONCRETE SUBCLASSES FOR TYPICAL STATUS CODES
  #
  # This makes it easy to rescue specific expected error types.

  class BadRequest < ClientError; end

  class Unauthorized < ClientError; end

  class NotFound < ClientError; end

  class NotAcceptable < ClientError; end

  class Gone < ClientError; end

  class UnprocessableEntity < ClientError; end

  class TooManyRequests < ClientError
    def retry_after
      case response.headers['RETRY_AFTER']
        when /^\d+$/
          DateTime.now + Rational(response.headers['RETRY_AFTER'].to_i, 86_400)
        when String
          begin
            DateTime.httpdate response.headers['RETRY_AFTER']
          rescue ArgumentError
            nil
          end
      end
    end
  end

  class InternalServerError < ServerError; end

  class BadGateway < GatewayError; end

  class ServiceUnavailable < GatewayError; end

  class GatewayTimeout < GatewayError; end
end
