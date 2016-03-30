require 'restify/version'

require 'hashie'
require 'concurrent'
require 'addressable/uri'
require 'addressable/template'

#
module Restify
  require 'restify/error'
  require 'restify/promise'

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
      Relation.new Context.new(uri, opts), uri
    end

    def adapter
      @adapter ||= begin
        require 'restify/adapter/em'
        Restify::Adapter::EM.new
      end
    end

    def adapter=(adapter)
      @adapter = adapter
    end
  end
end
