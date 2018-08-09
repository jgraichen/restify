# frozen_string_literal: true

module Restify
  module VERSION
    MAJOR = 1
    MINOR = 6
    PATCH = 0
    STAGE = nil
    STRING = [MAJOR, MINOR, PATCH, STAGE].reject(&:nil?).join('.').freeze

    def self.to_s
      STRING
    end
  end
end
