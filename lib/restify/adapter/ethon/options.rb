# frozen_string_literal: true

module Restify
  module Adapter
    class Ethon < Base
      #
      # libcurl options, converted to the arguments for
      # `curl_easy_setopt` once for performance reasons.
      #
      # @api private
      #
      class Options
        DEFINITIONS = ::Ethon::Curl.easy_options(nil)

        class << self
          def number(name)
            definition(name).fetch(:opt)
          end

          def definition(name)
            DEFINITIONS.fetch(name) do
              raise ArgumentError.new("Unknown libcurl option: #{name}")
            end
          end
        end

        # Options by name, e.g. `followlocation: true`, nil values are
        # skipped.
        #
        def initialize(options)
          @options = options.filter_map do |name, value|
            definition = self.class.definition(name)
            next if value.nil?

            compile(name, definition, value)
          end.freeze
        end

        def apply(easy)
          handle = easy.handle

          @options.each do |opt, type, value|
            if type
              ::Ethon::Curl.easy_setopt(handle, opt, type, value)
            else
              ::Ethon::Curl.set_option(opt, value, handle)
            end
          end
        end

        def to_a
          @options
        end

        private

        # Like `Ethon::Curls::Options#set_option` for the supported types.
        def compile(name, definition, value)
          opt = definition[:opt]

          case definition[:type]
            when :bool then [opt, :long, value && value != 0 ? 1 : 0]
            when :int, :time then [opt, :long, Integer(value)]
            when :enum then [opt, :long, lookup(name, definition, value)]
            when :bitmask then [opt, :long, Array(value).reduce(0) {|mask, v| mask | lookup(name, definition, v) }]
            when :string then [opt, :string, value.to_s]
            else [name, nil, value]
          end
        end

        def lookup(name, definition, value)
          return Integer(value) unless value.is_a?(Symbol) || value.is_a?(String)

          definition[:opts].fetch(value.to_sym) do
            raise ArgumentError.new("Unknown value for libcurl option #{name}: #{value.inspect}")
          end
        end
      end
    end
  end
end
