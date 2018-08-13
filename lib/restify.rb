# frozen_string_literal: true

require 'forwardable'

require 'restify/version'

require 'hashie'
require 'concurrent'
require 'addressable/uri'
require 'addressable/template'

module Restify
  require 'restify/error'
  require 'restify/logging'
  require 'restify/timeout'

  require 'restify/promise'
  require 'restify/registry'
  require 'restify/global'

  require 'restify/cache'
  require 'restify/context'
  require 'restify/resource'
  require 'restify/relation'

  require 'restify/link'
  require 'restify/request'
  require 'restify/response'

  module Adapter
    require 'restify/adapter/base'
    require 'restify/adapter/typhoeus'
  end

  module Processors
    require 'restify/processors/base'
    require 'restify/processors/base/parsing'

    require 'restify/processors/json'
    require 'restify/processors/msgpack'
  end

  PROCESSORS = [Processors::Json, Processors::Msgpack].freeze

  extend Global
end
