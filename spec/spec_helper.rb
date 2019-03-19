# frozen_string_literal: true

require 'rspec'
require 'webmock/rspec'

require 'simplecov'
SimpleCov.start

if ENV['CI']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

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

require 'webmock/rspec'
require 'rspec/collection_matchers'
require 'em-synchrony'

Dir[File.expand_path('spec/support/**/*.rb')].each {|f| require f }

RSpec.configure do |config|
  config.order = 'random'

  config.before(:suite) do
    ::Restify::Timeout.default_timeout = 2
  end

  config.before(:each) do
    Ethon.logger = ::Logging.logger[Ethon] if defined?(Ethon)

    ::Logging.logger.root.level = :debug
    ::Logging.logger.root.add_appenders ::Logging.appenders.stdout
  end

  config.warnings = true
  config.after(:suite) do
    EventMachine.stop if defined?(EventMachine) && EventMachine.reactor_running?
  end
end
