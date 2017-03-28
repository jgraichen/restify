# frozen_string_literal: true
module Restify
  module VERSION
    MAJOR = 1
    MINOR = 0
    PATCH = 1
    STAGE = :beta1
    STRING = [MAJOR, MINOR, PATCH, STAGE].reject(&:nil?).join('.').freeze

    def self.to_s
      STRING
    end
  end
end
