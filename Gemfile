# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in restify.gemspec
gemspec

gem 'em-http-request'
gem 'em-synchrony'
gem 'rake'
gem 'rake-release'
gem 'typhoeus'

group :test do
  gem 'simplecov'
  gem 'simplecov-cobertura'

  gem 'puma'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'webmock'
end

group :development, :lint do
  gem 'rubocop-config', github: 'jgraichen/my-rubocop', tag: 'v13'
end

group :development do
  gem 'redcarpet', platform: :ruby
  gem 'yard'
end

group :development, :test do
  gem 'pry', platforms: :mri
  gem 'pry-byebug', platforms: :mri
end
