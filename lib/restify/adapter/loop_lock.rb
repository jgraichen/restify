# frozen_string_literal: true

module Restify
  module Adapter
    #
    # Manages coordination for exclusive ownership of an event loop,
    # shared between a background thread and threads waiting on results.
    # This way, the event loop can run on waiting threads directly,
    # avoiding costly context switches to the background thread.
    #
    # Waiting threads have priority: the background thread only acquires
    # the loop while no thread is waiting for it, and is interrupted to
    # release it as soon as one is.
    #
    # Waiting threads can give up waiting once their result is
    # available, e.g. because another thread running the loop produced
    # it. Whoever runs the loop must call `#notify` after producing a
    # result.
    #
    class LoopLock
      # @yield Called when a waiting thread needs the background thread to
      #   release the loop, e.g. to wake it up from `select`.
      #
      def initialize(&interrupt)
        @interrupt = interrupt

        reset!
      end

      # Acquire the loop for a thread waiting on a result.
      #
      # @param timeout [Restify::Timeout, Numeric] Maximum time to wait,
      #   derived from the promise timeout of the waiting thread.
      #
      # @yieldreturn [Boolean] Whether the result is available, and
      #   the loop is not needed anymore.
      #
      # @return [Boolean] true when the calling thread holds the loop,
      #   false when the result is available or the timeout expired
      #   first.
      #
      def acquire(timeout, &done)
        timeout = Timeout.new(timeout)

        background = @mutex.synchronize do
          @waiters += 1
          @background
        end

        @interrupt&.call if background

        @mutex.synchronize do
          loop do
            return false if done&.call

            remaining = timeout.remaining
            return false unless remaining.positive?

            if free?
              @owner = Thread.current
              return true
            end

            @changed.wait(@mutex, remaining)
          end
        ensure
          @waiters -= 1

          # Let the background thread continue.
          @changed.broadcast if @waiters.zero?
        end
      end

      # Acquire the loop for the background thread. Blocks while any
      # other thread holds the loop or waits for it.
      def acquire_background
        @mutex.synchronize do
          @changed.wait(@mutex) until free? && @waiters.zero?

          @owner = Thread.current
          @background = true
        end
      end

      def release
        @mutex.synchronize do
          @owner = nil
          @background = false
          @changed.broadcast
        end
      end

      def owned?
        @owner.equal?(Thread.current)
      end

      def notify
        return unless @waiters.positive?

        @mutex.synchronize { @changed.broadcast }
      end

      # Forget all threads holding or waiting for the loop, e.g. in a
      # forked child process, where these threads do not exist.
      #
      # Must not be called while other threads use the lock.
      def reset!
        @mutex      = Mutex.new
        @changed    = ConditionVariable.new
        @owner      = nil
        @background = false
        @waiters    = 0
      end

      private

      # A thread holding the loop can be gone without releasing it, e.g.
      # when killed.
      def free?
        @owner.nil? || !@owner.alive?
      end
    end
  end
end
