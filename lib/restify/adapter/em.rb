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
          @pool = []
          @wait = []
          @used = 0
        end

        def get(request, timeout: 2)
          defer = Deferrable.new(request)
          defer.timeout(timeout, :timeout)
          defer.errback { @wait.delete(defer) }

          checkout(defer)

          defer
        end

        def release(conn)
          @pool.unshift(conn) if @pool.size < @size
          @used -= 1 if @used.positive?

          Restify.logger.debug(LOG_PROGNAME) do
            "[#{conn.uri}] Released to pool (#{@pool.size}/#{@used}/#{size})"
          end

          checkout(@wait.shift) if @wait.any? # checkout next waiting defer
        end

        alias << release

        def remove(conn)
          close(conn)

          Restify.logger.debug(LOG_PROGNAME) do
            "[#{conn.uri}] Removed from pool (#{@pool.size}/#{@used}/#{size})"
          end

          checkout(@wait.shift) if @wait.any? # checkout next waiting defer
        end

        def size
          @pool.size + @used
        end

        private

        def close(conn)
          @used -= 1 if @used.positive?
          @host[conn.uri.to_s] -= 1

          conn.close
        end

        # rubocop:disable AbcSize
        # rubocop:disable MethodLength
        def checkout(defer)
          origin = defer.request.uri.origin
          cindex = @pool.find_index {|conn| conn.uri == origin }

          if cindex
            @used += 1
            conn = @pool.delete_at(cindex)

            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Take connection from pool " \
              "(#{@pool.size}/#{@used}/#{size})"
            end

            defer.succeed(conn)
          elsif size < @size && @host[origin] < @per_host
            @used += 1
            conn = new(origin)

            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Add new connection to pool " \
              "(#{@pool.size}/#{@used}/#{size})"
            end

            defer.succeed(conn)
          elsif @pool.any? && @host[origin] < @per_host
            close(@pool.pop)

            @used += 1

            conn = new(origin)

            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Replaced connection from pool " \
              "(#{@pool.size}/#{@used}/#{size})"
            end

            defer.succeed(conn)
          else
            Restify.logger.debug(LOG_PROGNAME) do
              "[#{origin}] Wait for free slot " \
              "(#{@pool.size}/#{@used}/#{size})"
            end

            @wait << defer
          end
        end
        # rubocop:enable all

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

        class Deferrable
          include ::EventMachine::Deferrable

          attr_reader :request
          attr_reader :connection

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
