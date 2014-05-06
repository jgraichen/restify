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

    def initialize(opts = {})
      @method = opts.fetch(:method, 'GET')
      @uri    = opts.fetch(:uri) { fail ArgumentError, ':uri required.' }
    end
  end
end
