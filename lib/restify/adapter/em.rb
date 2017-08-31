# frozen_string_literal: true

require 'eventmachine'
require 'em-http-request'

module Restify
  module Adapter
    class EM < Base
      # rubocop:disable RedundantFreeze
      LOG_PROGNAME = 'restify.adapter.em'.freeze

      class Pool
        def initialize(size: 32, per_host: 6, connect_timeout: 2, inactivity_timeout: 10)
          @size = size
          @per_host = per_host
          @connect_timeout = connect_timeout
          @inactivity_timeout = inactivity_timeout

          @host = Hash.new {|h, k| h[k] = 0 }
          @available = []
          @queue = []
          @used = 0
        end

        def get(request, timeout: 2)
          defer = Deferrable.new(request)
          defer.timeout(timeout, :timeout)
          defer.errback { @queue.delete(defer) }

          checkout(defer)

          defer
        end

        def release(conn)
          @available.unshift(conn) if @available.size < @size
          @used -= 1 if @used.positive?

          Restify.logger.debug(LOG_PROGNAME) do
            "[#{conn.uri}] Released to pool (#{@available.size}/#{@used}/#{size})"
          end

          checkout(@queue.shift) if @queue.any? # checkout next waiting defer
        end

        alias << release

        def remove(conn)
          close(conn)

          Restify.logger.debug(LOG_PROGNAME) do
            "[#{conn.uri}] Removed from pool (#{@available.size}/#{@used}/#{size})"
          end

          checkout(@queue.shift) if @queue.any? # checkout next waiting defer
        end

        def size
          @available.size + @used
        end

        private

        def close(conn)
          @used -= 1 if @used.positive?
          @host[conn.uri.to_s] -= 1

          conn.close
        end

        def checkout(defer)
          origin = defer.request.uri.origin

          if (index = find_reusable_connection(origin))
            defer.succeed reuse_connection(index, origin)
          elsif can_build_new_connection?(origin)
            defer.succeed new_connection(origin)
          else
            queue defer
          end
        end

        def find_reusable_connection(origin)
          @available.find_index {|conn| conn.uri == origin }
        end

        def reuse_connection(index, origin)
          @used += 1
          @available.delete_at(index).tap do
            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Take connection from pool " \
                "(#{@available.size}/#{@used}/#{size})"
            end
          end
        end

        def new_connection(origin)
          # If we have reached the limit, we have to throw away the oldest
          # reusable connection in order to open a new one
          close_oldest if size >= @size

          @used += 1
          new(origin).tap do
            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Add new connection to pool " \
                "(#{@available.size}/#{@used}/#{size})"
            end
          end
        end

        def close_oldest
          close(@available.pop)

          Restify.logger.debug(LOG_PROGNAME) do
            "[#{origin}] Closed oldest connection in pool " \
              "(#{@available.size}/#{@used}/#{size})"
          end
        end

        def queue(defer)
          Restify.logger.debug(LOG_PROGNAME) do
            "[#{origin}] Wait for free slot " \
              "(#{@available.size}/#{@used}/#{size})"
          end

          @queue << defer
        end

        def new(origin)
          Restify.logger.debug(LOG_PROGNAME) do
            "Connect to '#{origin}' " \
            "(#{@connect_timeout}/#{@inactivity_timeout})..."
          end

          @host[origin] += 1

          EventMachine::HttpRequest.new origin,
            connect_timeout: @connect_timeout,
            inactivity_timeout: @inactivity_timeout
        end

        def can_build_new_connection?(origin)
          return false if @host[origin] >= @per_host

          size < @size || @available.any?
        end

        class Deferrable
          include ::EventMachine::Deferrable

          attr_reader :request

          def initialize(request)
            @request = request
          end

          def succeed(connection)
            @connection = connection
            super
          end
        end
      end

      def initialize(**kwargs)
        @pool = Pool.new(**kwargs)
      end

      # rubocop:disable MethodLength
      # rubocop:disable AbcSize
      # rubocop:disable BlockLength
      def call_native(request, writer)
        next_tick do
          defer = @pool.get(request)

          defer.errback do |error|
            writer.reject(error)
          end

          defer.callback do |conn|
            begin
              req = conn.send request.method.downcase,
                keepalive: true,
                redirects: 3,
                path: request.uri.normalized_path,
                query: request.uri.normalized_query,
                body: request.body,
                head: request.headers

              req.callback do
                writer.fulfill Response.new(
                  request,
                  req.last_effective_url,
                  req.response_header.status,
                  req.response_header,
                  req.response
                )

                if req.response_header['CONNECTION'] == 'close'
                  @pool.remove(conn)
                else
                  @pool << conn
                end
              end

              req.errback do
                @pool.remove(conn)
                writer.reject(req.error)
              end
            rescue Exception => ex # rubocop:disable RescueException
              @pool.remove(conn)
              writer.reject(ex)
            end
          end
        end
      end
      # rubocop:enable all

      private

      def next_tick(&block)
        ensure_running
        EventMachine.next_tick(&block)
      end

      def ensure_running
        return if EventMachine.reactor_running?

        Thread.new do
          begin
            EventMachine.run {}
          rescue => e
            puts "#{self.class} -> #{e}\n#{e.backtrace.join("\n")}"
            raise e
          end
        end
      end
    end
  end
end
