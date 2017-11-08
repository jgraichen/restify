# frozen_string_literal: true

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
        @sync    = sync
        @hydra   = ::Typhoeus::Hydra.new(pipelining: true, **options)
        @mutex   = Mutex.new

        start unless sync?
      end

      def sync?
        @sync
      end

      def call_native(request, writer)
        @mutex.synchronize do
          @hydra.queue convert(request, writer)
        end

        sync? ? @hydra.run : start
      end

      def queued?
        @mutex.synchronize do
          @hydra.queued_requests.any?
        end
      end

      private

      def convert(request, writer)
        req = ::Typhoeus::Request.new \
          request.uri,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body

        req.on_complete do |response|
          writer.fulfill convert_back(response, request)
        end

        req
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
        thread.run
      end

      def thread
        @thread ||= Thread.new do
          loop do
            begin
              Thread.stop unless queued?
              @hydra.run
            rescue StandardError => e
              puts "#{self.class}: #{e.message}"
            end
          end
        end
      end
    end
  end
end
