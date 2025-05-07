# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in restify.gemspec
gemspec

gem 'rake'
gem 'rake-release'

group :test do
  gem 'simplecov'
  gem 'simplecov-cobertura'

  gem 'puma'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'webmock'

  gem 'opentelemetry-instrumentation-ethon'
  gem 'opentelemetry-sdk'

  gem 'rubocop-config', github: 'jgraichen/my-rubocop', tag: 'v14'
end

group :development do
  gem 'redcarpet', platform: :ruby
  gem 'yard'
end
