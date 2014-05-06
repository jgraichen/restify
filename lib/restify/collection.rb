module Restify
  #
  class Collection < Array
    include Relations

    class << self
      def create(client, data, response)
        data = data.map { |s| Resource.create(client, s, nil) } if data
        new(data).tap do |c|
          c.relations.merge! response.relations(client) if response
        end
      end
    end
  end
end
