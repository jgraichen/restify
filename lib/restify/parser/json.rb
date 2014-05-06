module Restify
  #
  module Processors
    #
    # Decode JSON responses.
    class JSON
      def parse(str)
        MultiJSON.load(str)
      end

      def format
        :json
      end
    end
  end
end
