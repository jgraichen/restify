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

    def initialize(opts = {})
      @method  = opts.fetch(:method, :get).downcase
      @uri     = opts.fetch(:uri) { raise ArgumentError.new ':uri required.' }
      @data    = opts.fetch(:data, nil)
      @timeout = opts.fetch(:timeout, 300)
      @headers = opts.fetch(:headers, {})

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
