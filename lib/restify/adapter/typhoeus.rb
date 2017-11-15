# frozen_string_literal: true

require 'typhoeus'

module Restify
  module Adapter
    class Typhoeus < Base
      include Logging

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
          logger.debug { "[#{request.object_id}] Queue request #{request}" }
          @hydra.queue convert(request, writer)
          @hydra.dequeue_many
        end

        sync? ? @hydra.run : thread.run
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
          logger.debug { "[#{request.object_id}] Completed: #{response.code}" }

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
        return {} unless headers.respond_to?(:each_pair)

        headers.each_pair.each_with_object({}) do |header, memo|
          memo[header[0].upcase.tr('-', '_')] = header[1]
        end
      end

      def thread
        if @thread.nil? || !@thread.status
          # Recreate thread if nil or dead
          @thread = Thread.new { _loop }
        end

        @thread
      end

      def _loop
        loop { _run }
      end

      def _run
        if queued?
          logger.debug { 'Run hydra' }
          @hydra.run
          logger.debug { 'Hydra finished' }
        else
          logger.debug { 'Pause hydra thread' }
          Thread.stop
        end
      rescue StandardError => e
        logger.error(e)
      end
    end
  end
end
