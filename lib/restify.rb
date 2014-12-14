require 'restify/version'

require 'hashie'
require 'obligation'
require 'multi_json'
require 'addressable/uri'
require 'addressable/template'

#
module Restify
  require 'restify/http'
  require 'restify/error'
  require 'restify/relations'

  require 'restify/context'
  require 'restify/contextual'
  require 'restify/collection'
  require 'restify/resource'
  require 'restify/relation'

  require 'restify/link'
  require 'restify/request'
  require 'restify/response'

  class << self
    def new(uri, opts = {})
      Context.new(uri, http, nil, opts).request(:GET, uri)
    end

    def http
      @http ||= HTTP.new
    end
  end
end
