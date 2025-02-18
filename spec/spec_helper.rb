# frozen_string_literal: true

require 'rspec'
require 'rspec/collection_matchers'

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter 'spec'
end

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CoberturaFormatter,
]

require 'restify'

if ENV['ADAPTER']
  case ENV['ADAPTER'].to_s.downcase
    when 'em'
      require 'restify/adapter/em'
      Restify.adapter = Restify::Adapter::EM.new
    when 'em-pooled'
      require 'restify/adapter/pooled_em'
      Restify.adapter = Restify::Adapter::PooledEM.new
    when 'typhoeus'
      require 'restify/adapter/typhoeus'
      Restify.adapter = Restify::Adapter::Typhoeus.new
    when 'typhoeus-sync'
      require 'restify/adapter/typhoeus'
      Restify.adapter = Restify::Adapter::Typhoeus.new sync: true
    else
      raise "Invalid adapter: #{ENV['ADAPTER']}"
  end
end

require_relative 'support/stub_server'

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
    Restify::Timeout.default_timeout = 1.0
  end

  config.before do |example|
    next unless (adapter = example.metadata[:adapter])
    next if Restify.adapter.is_a?(adapter)

    skip 'Spec not enabled for current adapter'
  end

  config.before do
    Ethon.logger = Logging.logger[Ethon] if defined?(Ethon)

    Logging.logger.root.level = :debug
    Logging.logger.root.add_appenders Logging.appenders.stdout
  end

  config.warnings = true
  config.after(:suite) do
    EventMachine.stop if defined?(EventMachine) && EventMachine.reactor_running?
  end
end
