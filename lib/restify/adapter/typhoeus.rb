# frozen_string_literal: true

require 'typhoeus'

Ethon.logger = Logging.logger[Ethon]

module Restify
  module Adapter
    class Typhoeus < Base
      include Logging

      attr_reader :sync

      DEFAULT_HEADERS = {
        'Expect' => '',
        'Transfer-Encoding' => '',
      }.freeze

      DEFAULT_OPTIONS = {
        followlocation: true,
        tcp_keepalive: true,
        tcp_keepidle: 5,
        tcp_keepintvl: 5,
      }.freeze

      # Patch Hydra to restore the correct OpenTelemetry span when
      # adding the request, so that the Ethon instrumentation can
      # properly pick up the context where the Restify request
      # originated from.
      #
      # Handle exception from Ethon or WebMock too, and reject the
      # promise, so that the errors can be handled in user code.
      # Otherwise, the user would only receive a Promise timeout.
      module EasyOverride
        def add(request)
          OpenTelemetry::Trace.with_span(request._otel_span) do
            super(request)
          rescue Exception => e # rubocop:disable Lint/RescueException
            request._restify_writer.reject(e)
          end
        end
      end

      def initialize(sync: false, options: {}, **kwargs)
        @hydra = ::Typhoeus::Hydra.new(**kwargs)
        @hydra.extend(EasyOverride)

        @mutex   = Mutex.new
        @options = DEFAULT_OPTIONS.merge(options)
        @queue   = Queue.new
        @sync    = sync
        @thread  = nil

        super()
      end

      def sync?
        @sync
      end

      def call_native(request, writer)
        req = convert(request, writer)

        if sync?
          @hydra.queue(req)
          @hydra.run
        else
          debug 'request:add',
            tag: request.object_id,
            method: request.method.upcase,
            url: request.uri,
            timeout: request.timeout

          @queue << convert(request, writer)

          thread.run unless thread.status
        end
      end

      private

      def convert(request, writer)
        Request.new(
          request.uri,
          **@options,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body,
          timeout: request.timeout,
          connecttimeout: request.timeout,
        ).tap do |req|
          req._otel_span = OpenTelemetry::Trace.current_span
          req._restify_writer = writer

          req.on_complete do |response|
            debug 'request:complete',
              tag: request.object_id,
              status: response.code,
              message: response.return_message,
              timeout: response.timed_out?

            if response.timed_out? || response.code.zero?
              writer.reject \
                Restify::NetworkError.new(request, response.return_message)
            else
              writer.fulfill convert_back(response, request)
            end

            # Add all newly queued requests to active hydra, e.g. requests
            # queued in a completion callback.
            dequeue_all
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

        headers.each_pair.with_object({}) do |header, memo|
          memo[header[0].upcase.tr('-', '_')] = header[1]
        end
      end

      def thread
        if @thread.nil? || !@thread.status
          # Recreate thread if nil or dead
          debug 'hydra:spawn'

          @thread = Thread.new do
            Thread.current.name = 'Restify/Typhoeus Background'
            run
          end
        end

        @thread
      end

      def run
        runs = 0

        loop do
          if @queue.empty? && runs > 100
            debug 'hydra:gc'
            GC.start(full_mark: false, immediate_sweep: false)
            runs = 0
          end

          debug 'hydra:pop'

          # Wait for next item and add all available requests to hydra
          @hydra.queue @queue.pop
          dequeue_all

          debug 'hydra:run'
          @hydra.run
          runs += 1
          debug 'hydra:completed'
        rescue StandardError => e
          logger.error(e)
        end
      ensure
        debug 'hydra:exit'
      end

      def dequeue_all
        loop do
          @hydra.queue @queue.pop(true)
        rescue ThreadError
          break
        end
      end

      def _log_prefix
        "[#{object_id}/#{Thread.current.object_id}]"
      end

      class Request < ::Typhoeus::Request
        # Keep track of the OTEL span and the restify promise in the
        # queued Typhoeus request.
        #
        # We need to access these to restore the tracing context, or
        # bubble up exception that happen in the background thread after
        # queuing, but when Hydra adds the requests to libcurl.
        attr_accessor :_otel_span, :_restify_writer
      end
    end
  end
end
