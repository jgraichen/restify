# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in restify.gemspec
gemspec

gem 'rake'
gem 'rake-release'

group :benchmark do
  gem 'benchmark-ips'
  gem 'benchmark-memory'
end

group :test do
  gem 'simplecov', '~> 1.0'
  gem 'simplecov-cobertura'

  gem 'puma'
  gem 'rspec', '~> 3.0'
  gem 'webmock'

  gem 'opentelemetry-instrumentation-ethon'
  gem 'opentelemetry-sdk'

  gem 'rubocop-config', github: 'jgraichen/my-rubocop', tag: 'v15'
end
