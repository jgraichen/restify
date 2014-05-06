module Restify
  #
  class Client

    attr_reader :base

    #
    def request(method, path = '')
      request = Request.new method: method, uri: base.join(path)
      ::Restify.adapter.call(request).then do |response|
        data = if response.headers['Content-Type'] == 'application/json'
                 MultiJSON.load response.body
               else
                 {}
               end
        Resource.build(data, response)
      end
    end

    private

    def initialize(uri)
      @base = ::Addressable::URI.parse(uri)
    end
  end
end
