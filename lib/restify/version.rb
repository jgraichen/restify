module Restify
  module VERSION
    MAJOR = 0
    MINOR = 4
    PATCH = 0
    STAGE = 'b1'.freeze
    STRING = [MAJOR, MINOR, PATCH, STAGE].reject(&:nil?).join('.').freeze

    def self.to_s
      STRING
    end
  end
end
