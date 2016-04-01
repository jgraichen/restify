module Restify
  #
  class Promise < Concurrent::IVar
    def initialize(*dependencies, &task)
      @task         = task
      @dependencies = dependencies.flatten

      super(&nil)
    end

    def wait(timeout = nil)
      execute if pending?

      # if defined?(EventMachine)
      #   if incomplete?
      #     fiber = Fiber.current

      #     self.add_observer do
      #       EventMachine.next_tick { fiber.resume }
      #     end

      #     Fiber.yield
      #   else
      #     self
      #   end
      # else
        super
      # end
    end

    def then(&block)
      Promise.new([self], &block)
    end

    def execute(timeout = nil)
      synchronize { ns_execute timeout }
    end

    protected

    # @!visibility private
    def ns_execute(timeout)
      if compare_and_set_state(:processing, :pending)
        return unless @task || @dependencies.any?

        executor = Concurrent::SafeTaskExecutor.new \
          method(:ns_exec), rescue_exception: true

        success, value, reason = executor.execute

        complete success, value, reason
      end
    end

    # @!visibility private
    def ns_exec
      args  = @dependencies.any? ? @dependencies.map(&:value!) : []
      value = @task ? @task.call(*args) : args

      while value.is_a? Restify::Promise
        value = value.value!
      end

      value
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
