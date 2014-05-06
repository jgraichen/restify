module Restify
  #
  class Client

    attr_reader :base

    #
    def request(method, path = '')
      request = Request.new method: method, uri: base.join(path)
      ::Restify.adapter.call(request).then do |response|
        data = if response.headers['Content-Type'] == 'application/json'
                 MultiJson.load response.body
               else
                 {}
               end

        if data.is_a?(Array)
          Collection.create(self, data, response)
        else
          Resource.create(self, data, response)
        end
      end
    end

    private

    def initialize(uri)
      @base = ::Addressable::URI.parse(uri)
    end
  end
end
