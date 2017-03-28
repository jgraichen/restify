# frozen_string_literal: true
require 'active_support/notifications'

module Restify
  module Instrumentation
    def call(*args)
      if block_given?
        ::ActiveSupport::Notifications.instrument(*args, &Proc.new)
      else
        ::ActiveSupport::Notifications.instrument(*args)
      end
    end

    module_function :call
  end
end
