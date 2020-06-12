# frozen_string_literal: true

require 'eventmachine'
require 'em-http-request'

module Restify
  module Adapter
    class PooledEM < Base
      include Logging

      # This class maintains a pool of connection objects, grouped by origin,
      # and ensures limits for total parallel requests and per-origin requests.
      #
      # It does so by maintaining a list of already open, reusable connections.
      # When any of them are checked out for usage, it counts the usages to
      # prevent constraints being broken.
      class Pool
        include Logging

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

        # Request a connection from the pool.
        #
        # Attempts to checkout a reusable connection from the pool (or create a
        # new one). If any of the limits have been reached, the request will be
        # put onto a queue until other connections are released.
        #
        # Returns a Deferrable that succeeds with a connection instance once a
        # connection has been checked out (usually immediately).
        #
        # @return [Deferrable<Request>]
        #
        def get(request, timeout: 2)
          defer = Deferrable.new(request)
          defer.timeout(timeout, :timeout)
          defer.errback { @queue.delete(defer) }

          checkout(defer)

          defer
        end

        # Return a connection to the pool.
        #
        # If there are requests in the queue (due to one of the limits having
        # been reached), they will be given an attempt to use the released
        # connection.
        #
        # If no requests are queued, the connection will be held for reuse by a
        # subsequent request.
        #
        # @return [void]
        #
        def release(conn)
          @available.unshift(conn) if @available.size < @size
          @used -= 1 if @used > 0

          logger.debug do
            "[#{conn.uri}] Released to pool (#{@available.size}/#{@used}/#{size})"
          end

          checkout(@queue.shift) if @queue.any? # checkout next waiting defer
        end

        alias << release

        def remove(conn)
          close(conn)

          logger.debug do
            "[#{conn.uri}] Removed from pool (#{@available.size}/#{@used}/#{size})"
          end

          checkout(@queue.shift) if @queue.any? # checkout next waiting defer
        end

        # Determine the number of connections in the pool.
        #
        # This takes into account both reusable (idle) and used connections.
        #
        # @return [Integer]
        #
        def size
          @available.size + @used
        end

        private

        def close(conn)
          @used -= 1 if @used > 0
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
            logger.debug do
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
            logger.debug do
              "[#{origin}] Add new connection to pool " \
                "(#{@available.size}/#{@used}/#{size})"
            end
          end
        end

        def close_oldest
          close(@available.pop)

          logger.debug do
            "[#{origin}] Closed oldest connection in pool " \
              "(#{@available.size}/#{@used}/#{size})"
          end
        end

        def queue(defer)
          logger.debug do
            "[#{origin}] Wait for free slot " \
              "(#{@available.size}/#{@used}/#{size})"
          end

          @queue << defer
        end

        def new(origin)
          logger.debug do
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

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/BlockLength
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
            rescue Exception => e # rubocop:disable Lint/RescueException
              @pool.remove(conn)
              writer.reject(e)
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
          rescue StandardError => e
            logger.error(e)
            raise e
          end
        end
      end
    end
  end
end
