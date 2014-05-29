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

    def get(opts = {})
      request :get, opts
    end

    def post(opts = {})
      request :post, opts
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
