module Restify
  #
  module Adapter
    #
    class EM

      def call(request)
        Obligation.create do |w|
          next_tick do
            conn = ConnectionPool.get(request.uri)
            req  = conn.get keepalive: true,
                            path: request.uri.normalized_path,
                            query: request.uri.normalized_query
            req.callback do
              w.fulfill Response.new(req.response, req.response_header)
            end
          end
        end
      end

      private

      def next_tick(&block)
        ensure_running
        EventMachine.next_tick(&block)
      end

      def ensure_running
        Thread.new { EventMachine.run {} } unless EventMachine.reactor_running?
      end

      #
      class ConnectionPool
        class << self
          #
          def get(uri)
            connections[uri.origin] ||= begin
              EventMachine::HttpRequest.new(uri.origin)
            end
          end

          #
          def connections
            @connections ||= {}
          end
        end
      end
    end
  end
end
