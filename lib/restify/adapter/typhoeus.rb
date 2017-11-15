# frozen_string_literal: true

require 'typhoeus'

module Restify
  module Adapter
    class Typhoeus < Base
      # rubocop:disable RedundantFreeze
      LOG_PROGNAME = 'restify.adapter.typhoeus'.freeze

      attr_reader :sync

      DEFAULT_HEADERS = {
        'Expect' => '',
        'Transfer-Encoding' => ''
      }.freeze

      def initialize(sync: false, **options)
        @sync   = sync
        @hydra  = ::Typhoeus::Hydra.new(**options)
        @mutex  = Mutex.new
      end

      def sync?
        @sync
      end

      def call_native(request, writer)
        @mutex.synchronize do
          @hydra.queue convert(request, writer)
          @hydra.dequeue_many
        end

        sync? ? @hydra.run : start
      end

      def queued?
        @mutex.synchronize do
          @hydra.queued_requests.any? || @hydra.multi.easy_handles.count > 0
        end
      end

      private

      def convert(request, writer)
        req = ::Typhoeus::Request.new \
          request.uri,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body,
          followlocation: true,
          timeout: request.timeout,
          connecttimeout: request.timeout

        req.on_complete do |response|
          if response.timed_out?
            writer.reject Restify::Timeout.new request
          elsif response.code == 0
            writer.reject Restify::NetworkError.new response.return_message
          else
            writer.fulfill convert_back(response, request)
          end
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
              @hydra.run
              Thread.stop unless queued?
            rescue StandardError => e
              puts "#{self.class}: #{e.message}"
            end
          end
        end
      end
    end
  end
end
