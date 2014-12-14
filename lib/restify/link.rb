module Restify
  #
  # A {Link} represents a single entry from the Link header
  # of a HTTP response.
  #
  class Link
    #
    # Extract URI string.
    #
    # @return [String] URI string.
    #
    attr_reader :uri

    # Link metadata like "rel" if specified.
    #
    # @return [Hash<String, String>] Metadata.
    #
    attr_reader :metadata

    def initialize(uri, metadata = {})
      @uri      = uri
      @metadata = metadata
    end

    class << self
      REGEXP_URI = /<[^>]*>\s*/
      REGEXP_PAR = /;\s*\w+\s*=\s*/i
      REGEXP_QUT = /"[^"]*"\s*/
      REGEXP_ARG = /\w+\s*/i

      def parse(string)
        scanner = StringScanner.new(string.strip)

        catch(:invalid) do
          return parse_links(scanner)
        end

        fail ArgumentError,
             "Invalid token at #{scanner.pos}: '#{scanner.rest}'"
      end

      private

      def parse_links(scanner)
        links = []
        loop do
          if (link = parse_link(scanner))
            links << link
          elsif scanner.eos?
            return links
          else
            throw :invalid
          end
        end
      end

      def parse_link(scanner)
        if (m = scanner.scan(REGEXP_URI))
          uri    = m.strip[1..-2]
          params = parse_params(scanner)
          new uri, params
        else
          false
        end
      end

      def parse_params(scanner)
        params = {}
        loop do
          if (p = parse_param(scanner))
            params[p[0]] = p[1]
          elsif scanner.scan(/,\s*/) || scanner.eos?
            return params
          else
            throw :invalid
          end
        end
      end

      def parse_param(scanner)
        if (m = scanner.scan(REGEXP_PAR))
          key = m.strip[1..-2].strip
          [key, parse_value(scanner)]
        else
          false
        end
      end

      def parse_value(scanner)
        if (m = scanner.scan(REGEXP_QUT))
          m.strip[1..-2]
        elsif (m = scanner.scan(REGEXP_ARG))
          m.strip
        else
          throw :invalid
        end
      end
    end
  end
end
