module Restify
  #
  class Collection < Array
    include Result
    include Relations

    def initialize(client, data = [], response = nil)
      super data

      map! do |item|
        case item
          when Hash
            Resource.new client, item
          else
            item
        end
      end

      @client    = client
      @relations = response ? response.relations(client) : nil
    end
  end
end
