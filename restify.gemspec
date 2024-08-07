# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'restify/version'

Gem::Specification.new do |spec|
  spec.name          = 'restify'
  spec.version       = Restify::VERSION
  spec.authors       = ['Jan Graichen']
  spec.email         = ['jg@altimos.de']
  spec.summary       = 'An experimental hypermedia REST client.'
  spec.description   = 'An experimental hypermedia REST client that uses ' \
                       'parallel, keep-alive and pipelined requests by default.'
  spec.homepage      = 'https://github.com/jgraichen/restify'
  spec.license       = 'LGPL-3.0+'

  spec.files         = Dir['**/*'].grep(%r{^((bin|lib|test|spec|features)/|
                        .*\.gemspec|.*LICENSE.*|.*README.*|.*CHANGELOG.*)}mi)
  spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1.0'

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'addressable', '~> 2.3'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_runtime_dependency 'hitimes'
  spec.add_runtime_dependency 'logging', '~> 2.0'
  spec.add_runtime_dependency 'msgpack', '~> 1.2'
  spec.add_runtime_dependency 'rack'
  spec.add_runtime_dependency 'typhoeus', '~> 1.3'

  spec.add_development_dependency 'bundler'

  spec.metadata = {
    'rubygems_mfa_required' => 'true',
  }
end
