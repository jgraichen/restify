require 'active_support/hash_with_indifferent_access'

module Restify
  #
  # A {Link} represents a single entry from the Link header
  # of a HTTP response.
  #
  class Link
    #
    # URI of the link interpreted as a RFC6570 template.
    #
    # @return [Addressable::Template] Link URI.
    #
    attr_reader :uri

    # Link metadata like "rel" if specified.
    #
    # @return [HashWithIndifferentAccess<String, String>] Metadata.
    #
    attr_reader :metadata

    REGEXP_URI = /<[^>]*>\s*/
    REGEXP_PAR = /;\s*\w+\s*=\s*/i
    REGEXP_QUT = /"[^"]*"\s*/
    REGEXP_ARG = /\w+\s*/i

    def initialize(uri, metadata = {})
      @uri      = uri
      @metadata = HashWithIndifferentAccess.new(metadata)
    end

    class << self
      # TODO: Refactor
      def parse(string)
        links   = []
        scanner = StringScanner.new(string.strip)
        catch(:unknown_token) do
          loop do
            if (m = scanner.scan(REGEXP_URI))
              begin
                if (uri = Addressable::URI.parse(m.strip[1..-2]))
                  catch(:param) do
                    params = {}
                    loop do
                      if (m = scanner.scan(REGEXP_PAR))
                        key = m.strip[1..-2].strip
                        if (m = scanner.scan(REGEXP_QUT))
                          params[key] = m.strip[1..-2]
                        elsif (m = scanner.scan(REGEXP_ARG))
                          params[key] = m.strip
                        else
                          throw :unknown_token, true
                        end
                      elsif scanner.scan(/,\s*/) || scanner.eos?
                        links << new(uri, params)
                        throw :param
                      else
                        throw :unknown_token, true
                      end
                    end
                  end
                end
              rescue Addressable::URI::InvalidURIError
                raise ArgumentError, "Invalid URI: #{m.strip[1..-2]}"
              end
            elsif scanner.eos?
              return links
            else
              throw :unknown_token, true
            end
          end
        end && fail(ArgumentError,
                    "Invalid token at #{scanner.pos}: '#{scanner.rest}'")
      end
    end
  end
end
