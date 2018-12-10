# frozen_string_literal: true

module Restify
  class Promise < Concurrent::IVar
    def initialize(*dependencies, &task)
      @task         = task
      @dependencies = dependencies.flatten

      super(&nil)

      # When dependencies were passed in, but none are left after flattening,
      # then we don't have to wait for explicit dependencies or resolution
      # through a writer.
      if !@task && @dependencies.empty? && dependencies.any?
        complete true, [], nil
      end
    end

    def wait(timeout = nil)
      t = Timeout.new(timeout, self)

      execute(t) if pending?

      super
      raise t if incomplete?
      self
    end

    def then(&block)
      Promise.new([self], &block)
    end

    def execute(timeout = nil)
      synchronize { ns_execute timeout }
    end

    protected

    # @!visibility private
    def ns_execute(timeout = nil)
      return unless compare_and_set_state(:processing, :pending)
      return unless @task || @dependencies.any?

      executor = Concurrent::SafeTaskExecutor.new \
        method(:ns_exec), rescue_exception: true

      success, value, reason = executor.execute(timeout)

      complete success, value, reason
    end

    # @!visibility private
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
      def create
        promise = Promise.new
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
    end
  end
end
