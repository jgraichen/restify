# frozen_string_literal: true

require 'hitimes'

module Restify
  class Timeout
    class << self
      attr_accessor :default_timeout
    end

    # Default wait timeout of 300 seconds.
    self.default_timeout = 300

    def initialize(timeout, target = nil)
      @timeout = parse_timeout(timeout)
      @target = target

      @interval = ::Hitimes::Interval.new
      @interval.start
    end

    def wait_on!(ivar)
      ivar.value!(wait_interval).tap do
        raise self unless ivar.complete?
      end
    rescue ::Timeout::Error
      raise self
    end

    def timeout!
      raise self if wait_interval <= 0
    end

    def exception
      Error.new(@target)
    end

    private

    def wait_interval
      @timeout - @interval.to_f
    end

    def parse_timeout(value)
      return self.class.default_timeout if value.nil?

      begin
        value = Float(value)
      rescue ArgumentError
        raise ArgumentError.new \
          "Timeout must be an number but is #{value}"
      end

      raise ArgumentError.new "Timeout must be > 0 but is #{value.inspect}." unless value.positive?

      value
    end

    class << self
      def new(timeout, *args)
        return timeout if timeout.is_a?(self)

        super
      end
    end

    class Error < ::Timeout::Error
      attr_reader :target

      def initialize(target)
        @target = target

        if @target
          super "Operation on #{@target} timed out"
        else
          super 'Operation timed out'
        end
      end
    end
  end
end
