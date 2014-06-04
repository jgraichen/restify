module Restify
  #
  class Relation
    def initialize(client, uri_template)
      @client   = client
      @template = if uri_template.is_a?(Addressable::Template)
                    uri_template
                  else
                    Addressable::Template.new(uri_template)
                  end
    end

    def get(params = {})
      request :get, params
    end

    def post(data = {}, params = {})
      request :post, params.merge(data: data)
    end

    def put(data = {}, params = {})
      request :put, params.merge(data: data)
    end

    def patch(data = {}, params = {})
      request :patch, params.merge(data: data)
    end

    def delete(data = {}, params = {})
      request :delete, params.merge(data: data)
    end

    private

    attr_reader :client, :template

    def request(method, opts = {})
      keys   = template.variables - Client::RESERVED_KEYS
      params = opts.except!(keys)
      uri    = template.expand(params)

      client.request method, uri, opts
    end
  end
end
