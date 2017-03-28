# frozen_string_literal: true
module Restify
  #
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

    def initialize(opts = {})
      @method  = opts.fetch(:method, :get).downcase
      @uri     = opts.fetch(:uri) { raise ArgumentError.new ':uri required.' }
      @data    = opts.fetch(:data, nil)
      @headers = opts.fetch(:headers, {}).merge \
        'Content-Type' => 'application/json'
    end

    def body
      @body ||= begin
        JSON.dump(data) unless data.nil?
      end
    end
  end
end
