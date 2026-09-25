# frozen_string_literal: true

module Restify
  class Promise < Concurrent::IVar
    # A driver that can complete this promise in the waiting thread,
    # e.g. an adapter running its event loop. See `#wait`.
    #
    # @api private
    attr_writer :driver

    def initialize(*dependencies, &task)
      @task         = task
      @dependencies = dependencies.flatten
      @driver       = nil

      super(&nil)

      # When dependencies were passed in, but none are left after flattening,
      # then we don't have to wait for explicit dependencies or resolution
      # through a writer.
      complete(true, [], nil) if !@task && @dependencies.empty? && dependencies.any?
    end

    def wait(timeout = nil)
      t = Timeout.new(timeout, self)

      execute(t) if pending?

      # Let the driver run on the current thread instead of sleeping and
      # switching to another thread if possible. If unsupported, the
      # driver returns false.
      super unless incomplete? && @driver&.drive(self, t)

      raise t if incomplete?

      self
    end

    def then(&)
      Promise.new([self], &)
    end

    def execute(timeout = nil)
      synchronize { ns_execute timeout }
    end

    private

    def ns_execute(timeout = nil)
      return unless compare_and_set_state(:processing, :pending)
      return unless @task || @dependencies.any?

      begin
        value = ns_exec(timeout)
      rescue Exception => e # rubocop:disable Lint/RescueException
        complete(false, nil, e)
      else
        complete(true, value, nil)
      end
    end

    def ns_exec(timeout = nil)
      t = Timeout.new(timeout, self)

      args = @dependencies.map do |d|
        t.wait_on!(d)
      end

      value = @task ? @task.call(*args) : args
      value = t.wait_on!(value) while value.is_a?(Promise)
      value
    end

    class << self
      def create(driver: nil)
        promise = Promise.new
        promise.driver = driver
        yield Writer.new(promise)
        promise
      end

      def fulfilled(value)
        create do |writer|
          writer.fulfill value
        end
      end

      def rejected(value)
        create do |writer|
          writer.reject value
        end
      end
    end

    class Writer
      def initialize(promise)
        @promise = promise
      end

      def fulfill(value)
        @promise.send :complete, true, value, nil
      end

      def reject(reason)
        @promise.send :complete, false, nil, reason
      end

      def set
        fulfill(yield)
      rescue Exception => e # rubocop:disable Lint/RescueException
        reject(e)
      end
    end
  end
end
