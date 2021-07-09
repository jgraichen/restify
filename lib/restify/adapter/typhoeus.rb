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

      DEFAULT_OPTIONS = {
        followlocation: true,
        tcp_keepalive: true,
        tcp_keepidle: 5,
        tcp_keepintvl: 5
      }.freeze

      def initialize(sync: false, options: {}, **kwargs)
        @hydra   = ::Typhoeus::Hydra.new(**kwargs)
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

      # rubocop:disable Metrics/MethodLength
      def call_native(request, writer)
        req = convert(request, writer)

        if sync?
          req.run
        else
          debug 'request:add',
            tag: request.object_id,
            method: request.method.upcase,
            url: request.uri

          @queue << convert(request, writer)

          thread.run unless thread.status
        end
      end
      # rubocop:enable Metrics/MethodLength

      private

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def convert(request, writer)
        ::Typhoeus::Request.new(
          request.uri,
          **@options,
          method: request.method,
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body,
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

            # Add all newly queued requests to active hydra, e.g. requests
            # queued in a completion callback.
            dequeue_all
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

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

          @thread = Thread.new do
            Thread.current.name = 'Restify/Typhoeus Background'
            run
          end
        end

        @thread
      end

      # rubocop:disable Metrics/MethodLength
      def run
        loop do

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
      # rubocop:enable Metrics/MethodLength

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
    end
  end
end
