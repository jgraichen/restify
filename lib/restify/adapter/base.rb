# frozen_string_literal: true

require 'restify/adapter/telemetry'

module Restify
  module Adapter
    class Base
      prepend Telemetry

      def call(request)
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
