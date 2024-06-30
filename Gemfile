# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in restify.gemspec
gemspec

gem 'rake'
gem 'rake-release'
gem 'typhoeus'

group :test do
  gem 'codecov', require: false
  gem 'simplecov', require: false

  gem 'puma'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'webmock'

  gem 'my-rubocop', github: 'jgraichen/my-rubocop', ref: 'v5'
end

group :development do
  gem 'redcarpet', platform: :ruby
  gem 'yard'
end

group :development, :test do
  gem 'pry', platforms: :mri
  gem 'pry-byebug', platforms: :mri
end
