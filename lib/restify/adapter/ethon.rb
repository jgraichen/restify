# frozen_string_literal: true

require 'ethon'
require 'nio'

require 'restify/adapter/ethon/options'
require 'restify/adapter/ethon/easy'
require 'restify/adapter/ethon/event_loop'
require 'restify/adapter/ethon/pool'

module Restify
  module Adapter
    #
    # An adapter using libcurl's multi interface via `Ethon` in
    # `socket_action` mode, driven by a nio4r-based event loop.
    #
    # Requests are handed over to the event loop using a queue and the
    # loop is woken up via `NIO::Selector#wakeup`. Both are safe to call
    # from any thread.
    #
    # This is important because the event loop is run from either any
    # waiting thread or a dedicated background thread.
    #
    # The background thread that is spawned on demand and restarted if
    # it ever dies. A thread waiting on a request's promise takes over
    # the loop and runs it itself until the promise is complete, see
    # `#drive`. This avoids handing each request and response between
    # threads, which is expensive (thread wakeup). Only one thread runs
    # the loop at a time, therefore all libcurl and selector interaction
    # is still serialized.
    #
    class Ethon < Base
      include Logging

      # Restify follows relations from URLs in server responses, and
      # libcurl supports far more than HTTP, e.g. `file://` or `scp://`.
      # Therefore only HTTP-like protocols must ever be used, both for
      # the request itself and when following redirects.
      #
      # This is intentionally not configurable.
      PROTOCOLS = %i[http https].freeze

      # Set headers bypassing the wait for 100-continue responses many
      # servers do not send correctly.
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

      ENFORCED_OPTIONS = {
        # Do not use signal handlers in libcurl, as it would interfere
        # with the threads.
        nosignal: true,

        # Do not allow using and redirecting to unexpected (e.g. local)
        # protocols.
        protocols: PROTOCOLS,
        redir_protocols: PROTOCOLS,
      }.freeze

      # Maximum number of idle easy handles kept for reuse.
      POOL_SIZE = 64

      def initialize(options: {}, **multi)
        @options = Options.new({
          **DEFAULT_OPTIONS,
          **options,
          **ENFORCED_OPTIONS,
        })
        @multi_options = multi

        @mutex  = Mutex.new
        @thread = nil

        setup

        super()
      end

      def call_native(request, writer)
        check_fork!

        easy = convert(request, writer)

        debug 'request:add',
          tag: request.object_id,
          method: request.method.upcase,
          url: request.uri,
          timeout: request.timeout

        # Ensure the event loop is running and let it pick up the new
        # request.
        thread

        @events.enqueue(easy)
      end

      # Run the event loop in the calling thread until the promise is
      # complete or the timeout expires, see `Promise#wait` and
      # `EventLoop#drive`.
      #
      # This only processes transfers, i.e. fulfills or rejects the
      # adapter's promises. Callbacks chained with `Promise#then` still
      # only run in the thread waiting on them.
      #
      # Returns false when the loop cannot be run in the calling thread,
      # i.e. when waiting from within the loop itself.
      #
      def drive(promise, timeout)
        check_fork!

        @events.drive(promise, timeout)
      end

      private

      def driver
        self
      end

      def setup
        @pid    = Process.pid
        @pool   = Pool.new(size: POOL_SIZE) { Easy.new }
        @events = EventLoop.new(**@multi_options)
      end

      def check_fork!
        return if @pid == Process.pid

        @mutex.synchronize { forked! if @pid != Process.pid }
      end

      # A forked child process inherits the parent's event loop,
      # connections and sockets. They must neither be used nor cleaned
      # up here, as the parent still uses them.
      #
      # Therefore, abandon the state without releasing it, and set up
      # everything again.
      def forked!
        @events.forked!
        @pool.forked!

        @thread = nil
        setup
      end

      def convert(request, writer)
        @pool.checkout.tap do |easy|
          easy._otel_span = OpenTelemetry::Trace.current_span
          easy._restify_request = request
          easy._restify_writer = writer

          easy.prepare(request, @options)

          easy.on_complete do |completed|
            complete(completed, request, writer)

            @pool.release(completed)

            # Wake up threads waiting on the loop to check if their
            # result is available now.
            @events.notify
          end
        end
      end

      def complete(easy, request, writer)
        writer.set do
          if logger&.debug?
            debug 'request:complete',
              tag: request.object_id,
              status: easy.response_code,
              message: easy.return_code
          end

          easy.response(request)
        end
      rescue StandardError => e
        # This runs inside a libcurl callback, therefore no exception
        # must ever escape from here. Anything reaching this point could
        # not be handed to the promise anymore.
        error(e)
      end

      def thread
        @mutex.synchronize do
          # Spawn thread if not yet started, or recreate it if it died.
          if @thread.nil? || !@thread.status
            debug 'loop:spawn'

            events = @events
            @thread = Thread.new { events.run }
          end

          @thread
        end
      end

      def _log_prefix
        "[#{object_id}/#{Thread.current.object_id}]"
      end
    end
  end
end
