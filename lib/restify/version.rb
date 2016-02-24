module Restify
  module VERSION
    MAJOR = 0
    MINOR = 4
    PATCH = 0
    STAGE = nil
    STRING = [MAJOR, MINOR, PATCH, STAGE].reject(&:nil?).join('.').freeze

    def self.to_s
      STRING
    end
  end
end
