# frozen_string_literal: true

module Restify
  module VERSION
    MAJOR = 2
    MINOR = 0
    PATCH = 2
    STAGE = nil
    STRING = [MAJOR, MINOR, PATCH, STAGE].compact.join('.').freeze

    def self.to_s
      STRING
    end
  end
end
