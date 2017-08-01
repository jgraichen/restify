# frozen_string_literal: true

require 'rspec'
require 'webmock/rspec'

if ENV['CI'] || (defined?(:RUBY_ENGINE) && RUBY_ENGINE != 'rbx')
  require 'coveralls'
  Coveralls.wear! do
    add_filter 'spec'
  end
end

require 'restify'

if ENV['ADAPTER']
  case ENV['ADAPTER'].to_s.downcase
    when 'em-http-request'
      require 'restify/adapter/em'
      Restify.adapter = Restify::Adapter::EM.new
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

  config.before(:each) do
    Restify.logger.level = Logger::DEBUG
  end

  config.after(:each) do
    EventMachine.stop if defined?(EventMachine) && EventMachine.reactor_running?
  end
end
