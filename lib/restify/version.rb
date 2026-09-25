# frozen_string_literal: true

module Restify
  module VERSION
    MAJOR = 3
    MINOR = 0
    PATCH = 0
    STAGE = :rc1
    STRING = [MAJOR, MINOR, PATCH, STAGE].compact.join('.').freeze

    def self.to_s
      STRING
    end
  end
end
