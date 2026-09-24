# frozen_string_literal: true

module Restify
  module Logging
    def logger
      Restify.logger
    end

    def debug(message = nil, tag: nil, **kwargs)
      logger&.debug(_log_name) do
        [
          _log_prefix,
          *Array(tag),
          message,
          _fmt(**kwargs),
        ].map(&:to_s).reject(&:empty?).join(' ')
      end
    end

    def error(exception)
      logger&.error(_log_name) { exception }
    end

    def _log_name
      is_a?(Module) ? name : self.class.name
    end

    def _log_prefix
      nil
    end

    def _fmt(**kwargs)
      kwargs.each.map {|k, v| "#{k}=#{v}" }.join(' ')
    end
  end
end
