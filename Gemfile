source 'https://rubygems.org'

# Specify your gem's dependencies in restify.gemspec
gemspec

gem 'rake'
gem 'typhoeus'
gem 'em-http-request'
gem 'em-synchrony'

group :test do
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'webmock'
  gem 'coveralls'
end

group :development do
  gem 'yard'
  gem 'redcarpet', platform: :ruby
end

group :development, :test do
  gem 'pry', platforms: :mri
  gem 'pry-byebug', platforms: :mri
end
