# frozen_string_literal: true

require 'timeout'

module Restify
  class Timeout
    class << self
      attr_accessor :default_timeout
    end

    self.default_timeout = 300

    # @return [Float] Seconds to wait in total.
    attr_reader :duration

    def initialize(timeout, target = nil)
      @target = target
      @duration = parse_timeout(timeout)
      @deadline = now + @duration
    end

    def remaining
      @deadline - now
    end

    def exception
      Error.new(@target, @duration)
    end

    private

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def parse_timeout(value)
      value = self.class.default_timeout if value.nil?
      timeout = Float(value, exception: false)

      raise ArgumentError.new("Timeout must be a number but is #{value.inspect}") unless timeout
      raise ArgumentError.new("Timeout must be > 0 but is #{value.inspect}.") unless timeout.positive?
      raise ArgumentError.new("Timeout must be finite but is #{value.inspect}.") unless timeout.finite?

      timeout
    end

    class << self
      def new(timeout, target = nil)
        return timeout if timeout.is_a?(self)

        super
      end
    end

    class Error < ::Timeout::Error
      attr_reader :target, :duration

      def initialize(target, duration)
        @target = target
        @duration = duration

        if @target
          super("Operation on #{@target} timed out after #{duration}s")
        else
          super("Operation timed out after #{duration}s")
        end
      end
    end
  end
end
