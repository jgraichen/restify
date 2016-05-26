require 'restify/version'

require 'hashie'
require 'concurrent'
require 'addressable/uri'
require 'addressable/template'

#
module Restify
  require 'restify/error'
  require 'restify/promise'
  require 'restify/registry'
  require 'restify/global'

  require 'restify/context'
  require 'restify/resource'
  require 'restify/relation'

  require 'restify/link'
  require 'restify/request'
  require 'restify/response'

  module Adapter
    require 'restify/adapter/base'
  end

  module Processors
    require 'restify/processors/base'
    require 'restify/processors/json'
  end

  PROCESSORS = [Processors::Json]

  extend Global
end
