# frozen_string_literal: true

require 'ethon'
require 'nio'

Ethon.logger = Logging.logger[Ethon]

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

      # Restify follows relations from URLs in server responses, and
      # libcurl supports far more than HTTP, e.g. `file://` or `scp://`.
      # Therefore only HTTP-like protocols must ever be used, both for
      # the request itself and when following redirects.
      #
      # This is intentionally not configurable.
      PROTOCOLS = %i[http https].freeze

      INTERESTS = {
        none: nil,
        in: :r,
        out: :w,
        inout: :rw,
      }.freeze

      def initialize(options: {}, **)
        @options = DEFAULT_OPTIONS.merge(options)

        @selector = NIO::Selector.new
        @monitors = {}
        @timer    = nil

        @multi = ::Ethon::Multi.new(
          execution_mode: :socket_action,
          **,
        )

        # libcurl only stores the function pointers, therefore the procs
        # must be referenced here too, or they would be garbage
        # collected.
        @socketfunction = method(:on_socket).to_proc
        @timerfunction  = method(:on_timer).to_proc

        @multi.socketfunction = @socketfunction
        @multi.timerfunction  = @timerfunction

        @queue  = Queue.new
        @mutex  = Mutex.new
        @thread = nil
        @pid    = Process.pid

        # Wake up the background thread from `select` when a waiting
        # thread wants to run the loop.
        @loop = LoopLock.new { @selector.wakeup }

        super()
      end

      def call_native(request, writer)
        easy = convert(request, writer)

        debug 'request:add',
          tag: request.object_id,
          method: request.method.upcase,
          url: request.uri,
          timeout: request.timeout

        @queue << easy

        # Ensure the event loop is running and let it pick up the new
        # request.
        thread
        @selector.wakeup
      end

      # Run the event loop in the calling thread until the promise is
      # complete or the timeout expires, see `Promise#wait`.
      #
      # Several threads can wait at the same time, but only one runs the
      # loop. The others sleep until either their promise completes or
      # the loop is released. The background thread keeps processing
      # requests nobody waits on, but releases the loop as soon as a
      # thread starts waiting.
      #
      # This only processes transfers, i.e. fulfills or rejects the
      # adapter's promises. Callbacks chained with `Promise#then` still
      # only run in the thread waiting on them.
      #
      # Returns false when the loop cannot be run in the calling thread,
      # i.e. when waiting from within the loop itself.
      #
      def drive(promise, timeout) # rubocop:disable Naming/PredicateMethod
        return false if @loop.owned?

        while @loop.acquire(timeout) { promise.complete? }
          begin
            step(timeout.remaining) until promise.complete? || !timeout.remaining.positive?
          rescue StandardError => e
            logger.error(e)
          ensure
            @loop.release
          end
        end

        true
      end

      private

      def driver
        self
      end

      def convert(request, writer)
        Easy.new.tap do |easy|
          easy._otel_span = OpenTelemetry::Trace.current_span
          easy._restify_writer = writer

          easy.http_request(
            request.uri.to_s,
            request.method,
            request_options(request),
          )

          easy.on_complete do |completed|
            complete(completed, request, writer)

            # Wake up threads waiting on the loop to check if their
            # result is available now.
            @loop.notify
          end
        end
      end

      def request_options(request)
        # libcurl requires millisecond-based timeouts so fractional
        # seconds must be converted and rounded.
        timeout = request.timeout && (request.timeout * 1000).ceil

        @options.merge(
          headers: DEFAULT_HEADERS.merge(request.headers),
          body: request.body,
          timeout_ms: timeout,
          connecttimeout_ms: timeout,

          # Merged last, so that neither can be overridden via `options`.
          protocols: PROTOCOLS,
          redir_protocols: PROTOCOLS,

          # Do not use signal handlers in libcurl, as it would interfere
          # with the threads.
          nosignal: true,
        )
      end

      def complete(easy, request, writer)
        writer.set do
          code   = easy.return_code
          status = easy.response_code

          debug 'request:complete',
            tag: request.object_id,
            status: status,
            message: code

          if code != :ok
            raise Restify::NetworkError.new(
              request,
              ::Ethon::Curl.easy_strerror(code),
            )
          end

          if status.nil? || status.zero?
            raise Restify::NetworkError.new(
              request,
              'Response without HTTP status',
            )
          end

          convert_back(easy, request)
        end
      rescue StandardError => e
        # This runs inside a libcurl callback, therefore no exception
        # must ever escape from here. Anything reaching this point could
        # not be handed to the promise anymore.
        logger.error(e)
      end

      def convert_back(easy, request)
        ::Restify::Response.new(
          request,
          effective_uri(easy, request),
          easy.response_code,
          convert_headers(easy.response_headers),
          easy.response_body,
        )
      end

      def effective_uri(easy, request)
        url = easy.effective_url
        url ? Addressable::URI.parse(url) : request.uri
      end

      def convert_headers(raw)
        headers = {}
        return headers if raw.nil?

        # The raw headers can contain multiple blocks, e.g. from
        # informational responses or when following redirects; only use
        # the latest ones:
        block = raw.split(/\r?\n\r?\n/).reject {|b| b.strip.empty? }.last

        # Split on newlines that are not followed by whitespace to keep
        # folded header values together.
        block.to_s.split(/\r?\n(?!\s)/).each do |line|
          line = line.strip
          next if line.empty? || line.start_with?('HTTP/')

          key, value = line.split(':', 2)
          next if value.nil?

          key = key.strip.upcase.tr('-', '_')
          value = value.strip.gsub(/\r?\n\s*/, ' ')

          case (current = headers[key])
            when nil then headers[key] = value
            when Array then current << value
            else headers[key] = [current, value]
          end
        end

        headers
      end

      def thread
        @mutex.synchronize do
          # Spawn thread if not yet started, or recreate it if it died
          # (e.g. after fork). Reset the loop in the child process.
          if @thread.nil? || !@thread.status
            if @pid != Process.pid
              @pid = Process.pid
              @loop.reset!
            end

            debug 'loop:spawn'
            @thread = Thread.new { run }
          end

          @thread
        end
      end

      def run
        loop do
          @loop.acquire_background

          begin
            step
          ensure
            @loop.release
          end
        rescue StandardError => e
          logger.error(e)
        end
      ensure
        debug 'loop:exit'
      end

      # Run one iteration of the event loop. Must only be called by the
      # thread owning the loop.
      def step(limit = nil)
        dequeue_all

        # libcurl needs to be notified about its own timeouts, e.g. to
        # start newly added transfers or to time out stalled ones.
        timeout!

        timeout = select_timeout
        timeout = limit if limit && (timeout.nil? || timeout > limit)
        debug 'loop:select', timeout: timeout

        # nil on timeout; empty array when woken up
        @selector.select(timeout)&.each do |monitor|
          # libcurl can remove sockets while earlier events of the same
          # batch are processed, e.g. when a completed transfer tears
          # down other connections. Skip monitors that are gone by now.
          next unless @monitors[monitor.value].equal?(monitor)

          socket_action(monitor.value, readiness(monitor))
        end
      end

      def dequeue_all
        loop do
          easy = begin
            @queue.pop(true)
          rescue ThreadError
            break
          end

          add(easy)
        end
      end

      def add(easy)
        # Restore the OpenTelemetry span the request originated from, so
        # that the Ethon instrumentation picks up the correct parent
        # when the easy handle is added to libcurl.
        #
        # Handle exceptions from Ethon or WebMock too, and reject the
        # promise, so that the errors can be handled in user code.
        OpenTelemetry::Trace.with_span(easy._otel_span) do
          @multi.add(easy)
        rescue Exception => e # rubocop:disable Lint/RescueException
          easy._restify_writer.reject(e)
        end
      end

      # Seconds until libcurl wants to be called again, or nil to block
      # until a socket becomes ready or the loop is woken up.
      def select_timeout
        return nil unless @timer

        [@timer - now, 0].max
      end

      def timeout!
        return unless @timer
        return if now < @timer

        # Reset before invoking libcurl, as it will set a new timeout
        # from within the socket action.
        @timer = nil

        socket_action
      end

      def readiness(monitor)
        readiness = []
        readiness << :in if monitor.readable?
        readiness << :out if monitor.writable?
        readiness
      end

      def socket_action(socket = nil, readiness = 0)
        @multi.socket_action(socket, readiness)
      end

      # libcurl: called when asking for readiness monitoring
      def on_socket(_easy, socket, what, _userp, _socketp)
        debug 'socket:action', tag: socket, what: what

        if what == :remove
          @monitors.delete(socket)&.close
        else
          monitor = (@monitors[socket] ||= register(socket))
          monitor.interests = INTERESTS.fetch(what)
        end

        :ok
      rescue StandardError => e
        logger.error(e)
        :ok
      end

      # libcurl: called on timeout changes
      def on_timer(_handle, timeout_ms, _userp)
        debug 'timer:set', timeout: timeout_ms
        @timer = timeout_ms.negative? ? nil : now + (timeout_ms / 1000.0)

        :ok
      rescue StandardError => e
        logger.error(e)
        :ok
      end

      def register(socket)
        # FD owned by libcurl: IO/ruby must never close it
        io = IO.for_fd(socket, autoclose: false)

        @selector.register(io, :r).tap do |monitor|
          monitor.value = socket
        end
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def _log_prefix
        "[#{object_id}/#{Thread.current.object_id}]"
      end

      # Keep track of the OTEL span and the promise writer to reject on
      # errors in the background thread
      class Easy < ::Ethon::Easy
        attr_accessor :_otel_span, :_restify_writer
      end
    end
  end
end
