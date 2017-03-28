# frozen_string_literal: true
module Restify
  module Adapter
    class Base
      def call(request)
        ::Restify::Instrumentation.call 'restify.adapter.call',
          adapter: self, request: request

        Promise.create do |writer|
          call_native request, writer
        end
      end

      def call_native(_request, _writer)
        throw NotImplementedError.new 'Subclass responsibility'
      end
    end
  end
end
