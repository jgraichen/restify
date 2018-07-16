# frozen_string_literal: true

require 'json'

module Restify
  module Processors
    #
    # Decode plain JSON responses.
    #
    # JSON fields matching *_url will be parsed as relations.
    #
    class Json < Base
      include Parsing

      def deserialized_body
        ::JSON.parse(body)
      end

      class << self
        def accept?(response)
          response.content_type =~ %r{\Aapplication/json($|;)}
        end
      end
    end
  end
end
