require 'typhoeus'

module Restify
  module Adapter
    class Typhoeus < Base
      attr_reader :sync

      DEFAULT_HEADERS = {
        'Expect' => '',
        'Transfer-Encoding' => ''
      }.freeze

      def initialize(sync: false, **options)
        @queue   = Queue.new
        @sync    = sync
        @hydra   = ::Typhoeus::Hydra.new(pipelining: true, **options)

        start unless sync?
      end

      def sync?
        @sync
      end

      def queue(request, writer)
        if sync?
          @hydra.queue convert request, writer
          @hydra.run
        else
          @queue.push [request, writer]
        end
      end

      def call_native(request, writer)
        queue request, writer
      end

      private

      def convert(request, writer)
        req = ::Typhoeus::Request.new \
          request.uri,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body

        ::Restify::Instrumentation.call('restify.adapter.start', {
          adapter: self,
          request: request
        })

        req.on_complete {|response| handle(response, writer, request) }
        req
      end

      def handle(native_response, writer, request)
        response = convert_back(native_response, request)

        ::Restify::Instrumentation.call('restify.adapter.finish', {
          adapter: self,
          response: response
        })

        writer.fulfill(response)

        @hydra.queue convert(*@queue.pop(true)) while !@queue.empty?
      end

      def convert_back(response, request)
        uri     = request.uri
        status  = response.code
        body    = response.body
        headers = convert_headers(response.headers)

        ::Restify::Response.new(request, uri, status, headers, body)
      end

      def convert_headers(headers)
        headers.each_with_object({}) do |header, memo|
          memo[header[0].upcase.tr('-', '_')] = header[1]
        end
      end

      def start
        Thread.new do
          loop do
            begin
              while (req = convert(*@queue.pop))
                @hydra.queue req
                @hydra.run if @queue.empty?
              end
            rescue StandardError => e
              puts "#{self.class}: #{e.message}"
            end
          end
        end
      end
    end
  end
end
