require 'restify/adapter'

module Restify
  # @api private
  #
  class HTTP
    # @api private
    #
    def initialize
      @adapter = self.class.adapter
    end

    # @api private
    #
    # Request given path with given method.
    #
    # Returns an obligation that will return a collection or
    # resource or fail with a response error depending on
    # response from server.
    #
    def request(method, uri, data = nil, _opts = {})
      request = Request.new method: method, uri: uri, data: data

      @adapter.call(request)
    end

    class << self
      def adapter
        @adapter ||= Restify::Adapter::EM.new
      end
    end
  end
end
