require 'restify/version'

#
module Restify
  require 'restify/adapter'
  require 'restify/client'
  require 'restify/link'
  require 'restify/relation'
  require 'restify/request'
  require 'restify/resource'
  require 'restify/response'

  class << self
    def new(url)
      Client.new(url).request(:GET)
    end

    def adapter
      @adapter ||= Adapter::EM.new
    end

    def decode(response)
      decoder = decoders.find { |d| d.accept?(response) }
      if decoder
        decoder.decode(response)
      else
        UnsupportedFormatError.new \
          "Cannot decode `#{response.content_type}' response."
      end
    end
  end
end
