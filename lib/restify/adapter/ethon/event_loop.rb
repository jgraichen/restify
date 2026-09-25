# frozen_string_literal: true

module Restify
  module Adapter
    class Ethon < Base
      #
      # An event loop running libcurl's multi interface in
      # `socket_action` mode, waiting for sockets with nio4r.
      #
      # Can woken up to add new easy handles immediately but can run
      # from any thread. `LoopLock` ensures all interaction with libcurl
      # is still serialized and threads are correctly prioritized.
      #
      # @api private
      #
      class EventLoop
        include Logging

        INTERESTS = {
          none: nil,
          in: :r,
          out: :w,
          inout: :rw,
        }.freeze

        def initialize(**multi)
          @selector = NIO::Selector.new
          @monitors = {}
          @timer    = nil
          @queue    = Queue.new

          # libcurl only stores the function pointers, therefore the procs
          # must be referenced here too, or they would be garbage
          # collected.
          @socketfunction = method(:on_socket).to_proc
          @timerfunction  = method(:on_timer).to_proc

          @multi = ::Ethon::Multi.new(execution_mode: :socket_action, **multi)
          @multi.socketfunction = @socketfunction
          @multi.timerfunction  = @timerfunction

          # Wake up the background thread from `select` when a waiting
          # thread wants to run the loop.
          @lock = LoopLock.new { @selector.wakeup }
        end

        def enqueue(easy)
          @queue << easy
          @selector.wakeup
        end

        # Wake up threads waiting for the loop, e.g. after completing a
        # transfer, to check if their result is available now.
        def notify
          @lock.notify
        end

        # Run the loop in the calling thread until the promise is
        # complete or the timeout expires.
        #
        # Several threads can wait at the same time, but only one runs
        # the loop. The others sleep until either their promise
        # completes or the loop is released.
        #
        # @return [Boolean] false when the loop cannot be run in the
        #   calling thread, i.e. when waiting from within the loop
        #   itself.
        #
        def drive(promise, timeout) # rubocop:disable Naming/PredicateMethod
          return false if @lock.owned?

          while @lock.acquire(timeout) { promise.complete? }
            begin
              step(timeout.remaining) until promise.complete? || !timeout.remaining.positive?
            rescue StandardError => e
              error(e)
            ensure
              @lock.release
            end
          end

          true
        end

        # Run the loop whenever no thread waits for it. Blocks forever,
        # as meant for a background thread.
        def run
          loop do
            @lock.acquire_background

            begin
              step
            ensure
              @lock.release
            end
          rescue StandardError => e
            error(e)
          end
        ensure
          debug 'loop:exit'
        end

        # Forget the loop in a forked child process, without releasing
        # its libcurl handles, as they belong to the parent process.
        # Transfers not completed yet are rejected, as they were started
        # by the parent process too.
        #
        def forked!
          pending = @multi.easy_handles.dup
          pending << @queue.pop(true) until @queue.empty?

          @multi.handle.autorelease = false

          pending.each do |easy|
            easy.handle.autorelease = false
            easy._restify_writer.reject(
              Restify::NetworkError.new(
                easy._restify_request,
                'Request started before fork',
              ),
            )
          end

          nil
        end

        private

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
            # libcurl can remove sockets while earlier events of the
            # same batch are processed, e.g. when a completed transfer
            # tears down other connections. Skip monitors that are gone
            # by now.
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
          # Restore the OpenTelemetry span the request originated from,
          # so that the Ethon instrumentation picks up the correct
          # parent when the easy handle is added to libcurl.
          #
          # Handle exceptions from Ethon or WebMock too, and reject the
          # promise, so that the errors can be handled in user code.
          OpenTelemetry::Trace.with_span(easy._otel_span) do
            @multi.add(easy)
          rescue Exception => e # rubocop:disable Lint/RescueException
            easy._restify_writer.reject(e)
          end
        end

        # Seconds until libcurl wants to be called again, or nil to
        # block until a socket becomes ready or the loop is woken up.
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
          error(e)
          :ok
        end

        # libcurl: called on timeout changes
        def on_timer(_handle, timeout_ms, _userp)
          debug 'timer:set', timeout: timeout_ms
          @timer = timeout_ms.negative? ? nil : now + (timeout_ms / 1000.0)

          :ok
        rescue StandardError => e
          error(e)
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
      end
    end
  end
end
