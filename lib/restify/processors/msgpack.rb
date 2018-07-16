# frozen_string_literal: true

module Restify
  #
  module Processors
    #
    # Decode binary Msgpack responses.
    #
    # Fields matching *_url will be parsed as relations.
    #
    # This is intended to work as a drop-in performance
    # upgrade for the JSON processors. The two are 100%
    # compatible.
    #
    class Msgpack < Base
      def load
        context.parse ::MessagePack.unpack(body), response: response
      end

      class << self
        def accept?(response)
          response.content_type =~ %r{\Aapplication/(x-)?msgpack($|;)}
        end
      end
    end
  end
end
