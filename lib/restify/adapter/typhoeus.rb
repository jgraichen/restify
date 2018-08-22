# frozen_string_literal: true

require 'typhoeus'

::Ethon.logger = ::Logging.logger[Ethon]

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
        @signal = ConditionVariable.new
      end

      def sync?
        @sync
      end

      def call_native(request, writer)
        req = convert(request, writer)

        if sync?
          req.run
        else
          @mutex.synchronize do
            debug 'request:add',
              tag: request.object_id,
              method: request.method.upcase,
              url: request.uri

            @hydra.queue(req)
            @hydra.dequeue_many

            thread.run unless thread.status
          end

          debug 'request:signal', tag: request.object_id

          @signal.signal
        end
      end

      private

      def convert(request, writer)
        ::Typhoeus::Request.new(
          request.uri,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body,
          followlocation: true,
          timeout: request.timeout,
          connecttimeout: request.timeout
        ).tap do |req|
          req.on_complete do |response|
            debug 'request:complete',
              tag: request.object_id,
              status: response.code

            if response.timed_out?
              writer.reject Restify::Timeout.new request
            elsif response.code.zero?
              writer.reject \
                Restify::NetworkError.new(request, response.return_message)
            else
              writer.fulfill convert_back(response, request)
            end
          end
        end
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
          debug 'hydra:spawn'

          @thread = Thread.new { _loop }
        end

        @thread
      end

      def _loop
        Thread.current.name = 'Restify/Typhoeus Background'
        loop { _run }
      end

      def _ongoing?
        @hydra.queued_requests.any? || @hydra.multi.easy_handles.any?
      end

      def _run
        debug 'hydra:run'
        @hydra.run while _ongoing?
        debug 'hydra:completed'

        @mutex.synchronize do
          return if _ongoing?

          debug 'hydra:pause'
          @signal.wait(@mutex, 60)
          debug 'hydra:resumed'
        end
      rescue StandardError => e
        logger.error(e)
      end

      def _log_prefix
        "[#{object_id}/#{Thread.current.object_id}]"
      end
    end
  end
end
