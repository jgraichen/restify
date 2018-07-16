# frozen_string_literal: true

require 'msgpack'

module Restify
  module Processors
    #
    # Decode messagepack encoded responses.
    #
    # Fields matching *_url will be parsed as relations.
    #
    class Msgpack < Base
      include Parsing

      def deserialized_body
        ::MessagePack.unpack(body)
      end

      class << self
        def accept?(response)
          response.content_type =~ %r{\Aapplication/(x-)?msgpack($|;)}
        end
      end
    end
  end
end
