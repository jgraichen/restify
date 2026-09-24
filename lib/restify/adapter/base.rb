# frozen_string_literal: true

require 'restify/adapter/telemetry'

module Restify
  module Adapter
    class Base
      prepend Telemetry

      def call(request)
        Promise.create(driver:) do |writer|
          call_native request, writer
        end
      end

      def call_native(_request, _writer)
        raise NotImplementedError.new 'Subclass responsibility'
      end

      private

      # Adapters that can process requests in the thread waiting on the
      # returned promise return an object responding to
      # `#drive(promise, timeout)` here, see `Promise#wait`.
      def driver
        nil
      end
    end
  end
end
