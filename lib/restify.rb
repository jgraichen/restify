require 'restify/version'

require 'hashie'
require 'obligation'
require 'addressable/uri'
require 'addressable/template'

#
module Restify
  require 'restify/http'
  require 'restify/error'

  require 'restify/context'
  require 'restify/resource'
  require 'restify/relation'

  require 'restify/link'
  require 'restify/request'
  require 'restify/response'

  module Processors
    require 'restify/processors/base'
    require 'restify/processors/json'
  end

  PROCESSORS = [Processors::Json]

  class << self
    def new(uri, opts = {})
      Context.new(uri, http).request(:GET, uri)
    end

    def http
      @http ||= HTTP.new
    end
  end
end
