require 'eventmachine'
require 'em-http-request'

module Restify
  #
  module Adapter
    #
    class EM
      class Connection
        class << self
          def open(uri)
            connections[uri.origin] ||= new uri.origin
          end

          def connections
            @connections ||= {}
          end
        end

        attr_reader :origin

        def initialize(origin)
          @origin = origin
        end

        def requests
          @requests ||= []
        end

        def call(request, writer)
          requests << [request, writer]
          process_next if requests.size == 1
        end

        def connection
          @connection ||= EventMachine::HttpRequest.new(origin)
        end

        def process_next
          return if requests.empty?

          request, writer = requests.first
          req = connection.send request.method.downcase,
                                keepalive: true,
                                redirects: 3,
                                path: request.uri.normalized_path,
                                query: request.uri.normalized_query,
                                body: request.body,
                                head: request.headers

          req.callback do
            requests.shift

            writer.fulfill Response.new(
              request,
              req.response_header.status,
              req.response_header,
              req.response
            )

            if req.response_header['CONNECTION'] == 'close'
              @connection = nil
              @pipeline   = false
            end

            process_next
          end

          req.errback do
            requests.shift
            @connection = nil

            begin
              raise RuntimeError.new \
                "(#{req.response_header.status}) #{req.error}"
            rescue => e
              writer.reject e
            end
          end
        end
      end

      def call(request)
        Obligation.create do |writer|
          next_tick do
            Connection.open(request.uri).call(request, writer)
          end
        end
      end

      private

      def next_tick(&block)
        ensure_running
        EventMachine.next_tick(&block)
      end

      def ensure_running
        Thread.new do
          begin
            EventMachine.run {}
          rescue => e
            puts "Resitfy::Adapter::EM -> #{e}\n#{e.backtrace.join("\n")}"
            raise e
          end
        end unless EventMachine.reactor_running?
      end
    end
  end
end
