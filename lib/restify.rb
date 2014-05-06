require 'restify/version'
require 'addressable/uri'
require 'addressable/template'
require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/module/delegation'
require 'multi_json'

#
module Restify
  require 'restify/adapter'
  require 'restify/client'
  require 'restify/relations'
  require 'restify/collection'
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
