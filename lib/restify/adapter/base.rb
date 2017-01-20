module Restify
  module Adapter
    class Base
      def call(request)
        Promise.create do |writer|
          call_native request, writer
        end
      end

      def call_native(request, writer)
        throw NotImplementedError.new '#call_native not implemented. Subclass responsibility.'
      end
    end
  end
end