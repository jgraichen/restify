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

    def initialize(opts = {})
      @method = opts.fetch(:method, :get)
      @uri    = opts.fetch(:uri) { fail ArgumentError, ':uri required.' }
      @data   = opts.fetch(:data, nil)
    end

    def body
      @body ||= MultiJson.dump(data)
    end

    def headers
      {
        'Content-Type' => 'application/json'
      }
    end
  end
end
