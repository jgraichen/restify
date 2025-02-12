# frozen_string_literal: true

module Restify
  class Request
    #
    # HTTP method.
    #
    # @return [String] HTTP method.
    #
    attr_reader :method

    # Request URI.
    #
    # @return [String] Request URI.
    #
    attr_reader :uri

    # Request data.
    #
    attr_reader :data

    # Request headers
    #
    attr_reader :headers

    # Request timeout in seconds
    #
    # Defaults to 300 seconds.
    #
    attr_reader :timeout

    def initialize(uri:, method: :get, data: nil, timeout: 300, headers: {})
      @uri     = uri
      @method  = method.to_s.downcase
      @data    = data
      @timeout = timeout
      @headers = headers

      @headers['Content-Type'] ||= 'application/json' if json?
    end

    def body
      @body ||= json? ? JSON.dump(@data) : @data
    end

    def to_s
      "#<#{self.class} #{method.upcase} #{uri}>"
    end

    private

    def json?
      return false if @data.nil?
      return false if @data.is_a? String

      true
    end
  end
end
