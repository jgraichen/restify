# frozen_string_literal: true

module Restify
  #

  # A {Timeout} is raised when a request or promise times out.
  #
  class Timeout < StandardError
    attr_reader :source

    def initialize(source)
      super "Operation with #{source.class} has timed out"

      @source = source
    end
  end

  # A {NetworkError} is raised on unusual network exceptions such as
  # unresolvable hosts or disconnects.
  #
  class NetworkError < StandardError
  end

  # A {ResponseError} is returned on a non-successful
  # response from server. Usually it will either be a
  # {ClientError} or a {ServerError}.
  #
  class ResponseError < StandardError
    attr_reader :response

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
end
