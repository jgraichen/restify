module Restify
  #
  class Promise < Concurrent::IVar
    def initialize(*dependencies, &task)
      @task         = task || proc { |*args| args }
      @dependencies = dependencies.flatten

      super(&nil)
    end

    def wait(timeout = nil)
      if @dependencies.any? && pending?
        execute
      end

      super
    end

    def then(&block)
      Promise.new([self], &block)
    end

    def execute
      synchronize { ns_execute }
    end

    protected

    # @!visibility private
    def ns_execute
      return unless pending?

      executor = Concurrent::SafeTaskExecutor.new \
        method(:eval_dependencies), rescue_exception: true
      success, value, reason = executor.execute(@dependencies)

      if success
        ns_execute_task(*value)
      else
        complete false, nil, reason
      end
    end

    # @!visibility private
    def ns_execute_task(*args)
      if compare_and_set_state(:processing, :pending)
        success, value, reason = Concurrent::SafeTaskExecutor.new(@task, rescue_exception: true).execute(*args)

        while success && value.is_a?(Concurrent::IVar)
          success, value, reason = value.wait, value.value, value.reason
        end

        complete success, value, reason
      end
    end

    # @!visibility private
    def eval_dependencies(dependencies)
      dependencies.map(&method(:eval_dependency))
    end

    # @!visibility private
    def eval_dependency(dependency)
      if dependency.is_a? Concurrent::IVar
        eval_dependency eval_dependency_value dependency
      else
        dependency
      end
    end

    def eval_dependency_value(dependency)
      if dependency.complete?
        return dependency.value!
      end

      if EM.reactor_thread?
        fiber = Fiber.current

        dependency.add_observer {
          fiber.resume
        }

        Fiber.yield
      end

      dependency.value!
    end

    class << self
      def create
        promise = Promise.new
        yield Writer.new(promise)
        promise
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
