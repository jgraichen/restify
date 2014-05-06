module Restify
  #
  class Response

    attr_reader :body, :headers

    def initialize(body, headers)
      @body    = body
      @headers = headers
    end

    def links
      @links ||= begin
        if headers['Link']
          begin
            Link.parse(headers['Link'])
          rescue ArgumentError => e
            warn e
            []
          end
        else
          []
        end
      end
    end

    def relations(client)
      relations = {}
      links.each do |link|
        if (rel = link.metadata['rel'])
          relations[rel] = Relation.new(client, link.uri)
        end
      end
      relations
    end

    class << self
      def build(body, headers)
        Class.new(self) do

        end.new(body, headers)
      end
    end
  end
end
