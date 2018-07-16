# frozen_string_literal: true

require 'json'

module Restify
  #
  module Processors
    #
    # Decode plain JSON responses.
    #
    # JSON fields matching *_url will be parsed as relations.
    #
    class Json < Base
      def load
        context.parse ::JSON.parse(body), response: response
      end

      class << self
        def accept?(response)
          response.content_type =~ %r{\Aapplication/json($|;)}
        end

        def indifferent_access?
          @indifferent_access
        end

        attr_writer :indifferent_access
      end

      self.indifferent_access = true
    end
  end
end
