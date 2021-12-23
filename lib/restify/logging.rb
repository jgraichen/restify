# frozen_string_literal: true

require 'logging'

module Restify
  module Logging
    def logger
      @logger ||= ::Logging.logger[self]
    end

    def debug(message = nil, tag: nil, **kwargs)
      logger.debug do
        [
          _log_prefix,
          *Array(tag),
          message,
          _fmt(**kwargs),
        ].map(&:to_s).reject(&:empty?).join(' ')
      end
    end

    def _log_prefix
      nil
    end

    def _fmt(**kwargs)
      kwargs.each.map {|k, v| "#{k}=#{v}" }.join(' ')
    end
  end
end
