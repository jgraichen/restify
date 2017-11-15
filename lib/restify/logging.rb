# frozen_string_literal: true

require 'logging'

module Restify
  module Logging
    def logger
      @logger ||= ::Logging.logger[self]
    end
  end
end
