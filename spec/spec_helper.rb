require 'rspec'
require 'webmock/rspec'

if ENV['CI'] || (defined?(:RUBY_ENGINE) && RUBY_ENGINE != 'rbx')
  require 'coveralls'
  Coveralls.wear! do
    add_filter 'spec'
  end
end

require 'restify'

require 'eventmachine'
require 'rspec/collection_matchers'

Dir[File.expand_path('spec/support/**/*.rb')].each {|f| require f }

RSpec.configure do |config|
  config.order = 'random'

  config.after(:each) do
    EventMachine.stop if EventMachine.reactor_running?
  end
end
