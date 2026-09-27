# frozen_string_literal: true

module Restify
  class Promise
    class AlreadyCompleteError < StandardError; end

    # @api private
    attr_writer :driver

    # @api private
    attr_reader :reason

    def initialize(*dependencies, &task)
      @mutex        = Mutex.new
      @condition    = nil
      @observers    = nil
      @driver       = nil
      @state        = :pending
      @value        = nil
      @reason       = nil
      @task         = task
      @dependencies = dependencies.empty? ? nil : dependencies.flatten

      # When dependencies were passed in, but none are left after
      # flattening, then we don't have to wait for explicit dependencies
      # or resolution through a writer.
      fulfill([]) if !@task && @dependencies&.empty?
    end

    def pending?
      @state == :pending
    end

    def fulfilled?
      @state == :fulfilled
    end

    def rejected?
      @state == :rejected
    end

    def complete?
      @state == :fulfilled || @state == :rejected
    end

    def incomplete?
      !complete?
    end

    # Wait until the promise is complete.
    #
    # @param timeout [Numeric, Restify::Timeout, nil] Maximum seconds
    #   to wait, or `Restify::Timeout.default_timeout` if nil.
    #
    # @raise [Restify::Timeout::Error] When the timeout expired first.
    #
    # @return [self]
    #
    def wait(timeout = nil)
      return self if complete?

      timeout = Timeout.new(timeout, self)

      # Let the driver run on the current thread instead of sleeping and
      # switching to another thread if possible. The driver returns when
      # the promise is complete, the timeout expired, or it cannot run
      # here.
      @driver&.drive(self, timeout)

      until complete?
        remaining = timeout.remaining
        raise timeout unless remaining.positive?

        run(timeout) if claim(remaining)
      end

      self
    end

    # Wait until the promise is complete, and return its value, or nil
    # if it was rejected.
    #
    # @see #wait
    #
    def value(timeout = nil)
      wait(timeout)
      @value
    end

    # Wait until the promise is complete, and return its value, or raise
    # the reason it was rejected with.
    #
    # @see #wait
    #
    def value!(timeout = nil)
      wait(timeout)
      raise @reason if rejected?

      @value
    end

    # Return a new promise that will be fulfilled with the result of the
    # given block once this promise is complete.
    #
    def then(&)
      Promise.new(self, &)
    end

    # @api private
    #
    def add_observer(&block)
      complete = @mutex.synchronize do
        (@observers ||= []) << block unless complete?
        complete?
      end

      yield(@value, @reason) if complete

      self
    end

    private

    def fulfill(value)
      complete(:fulfilled, value, nil)
    end

    def reject(reason)
      complete(:rejected, nil, reason)
    end

    def complete(state, value, reason)
      observers = @mutex.synchronize do
        raise AlreadyCompleteError.new("Promise already #{@state}") if complete?

        # Set the state last, as it is read without holding the lock:
        @value  = value
        @reason = reason
        @state  = state

        # Release everything not needed anymore:
        @task = @dependencies = nil

        @condition&.broadcast

        @observers.tap { @observers = nil }
      end

      observers&.each do |observer|
        observer.call(value, reason)
      rescue StandardError => e
        Restify.logger&.error(self.class.name) { e }
      end

      self
    end

    # Claim running the task for the current thread, or sleep until the
    # promise is complete, or can be claimed, e.g. because another
    # thread gave up running it.
    #
    # The mutex is only held to claim, not while running the task. Other
    # threads sleep on the condition variable with their own remaining
    # time, whereas blocking on the mutex could not time out.
    #
    def claim(remaining)
      @mutex.synchronize do
        next false if complete?

        if @state == :pending && (@task || @dependencies)
          @state = :processing
          next true
        end

        (@condition ||= ConditionVariable.new).wait(@mutex, remaining)
        false
      end
    end

    def run(timeout)
      until complete?
        if (rejected = @dependencies&.find {|d| d.wait(timeout).rejected? })
          return reject(rejected.reason)
        end

        args = @dependencies&.map(&:value)

        begin
          value = @task ? @task.call(*args) : args
        rescue Exception => e # rubocop:disable Lint/RescueException
          return reject(e)
        end

        if value.is_a?(Promise)
          @dependencies = [value]
          @task = ->(v) { v }
        else
          fulfill(value)
        end
      end
    ensure
      # Give up the claim when the timeout expired, or the thread was
      # killed. Another waiting thread can take over, and continue with
      # the dependencies completed so far.
      if @state == :processing
        @mutex.synchronize do
          @state = :pending
          @condition&.broadcast
        end
      end
    end

    class << self
      def create(driver: nil)
        promise = new
        promise.driver = driver
        yield Writer.new(promise)
        promise
      end

      def fulfilled(value)
        new.send(:fulfill, value)
      end

      def rejected(reason)
        new.send(:reject, reason)
      end
    end

    class Writer
      def initialize(promise)
        @promise = promise
      end

      def fulfill(value)
        @promise.send(:fulfill, value)
      end

      def reject(reason)
        @promise.send(:reject, reason)
      end

      def set
        fulfill(yield)
      rescue Exception => e # rubocop:disable Lint/RescueException
        reject(e)
      end
    end
  end
end
