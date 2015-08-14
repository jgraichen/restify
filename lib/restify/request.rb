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
      @method = opts.fetch(:method, :get).downcase
      @uri    = opts.fetch(:uri) { raise ArgumentError.new ':uri required.' }
      @data   = opts.fetch(:data, nil)
    end

    def body
      @body ||= begin
        JSON.dump(data) unless data.nil?
      end
    end

    def headers
      {
        'Content-Type' => 'application/json'
      }
    end
  end
end
