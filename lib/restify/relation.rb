module Restify
  #
  class Relation

    def initialize(client, uri_template)
      @client = client
      @uri    = if uri_template.is_a?(Addressable::Template)
                  uri_template
                else
                  Addressable::Template.new(uri_template)
                end
    end

    def get(opts = {})
      @client.request(:GET, @uri.expand(opts))
    end
  end
end
