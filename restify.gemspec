# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'restify/version'

Gem::Specification.new do |spec|
  spec.name          = 'restify'
  spec.version       = Restify::VERSION
  spec.authors       = ['Jan Graichen']
  spec.email         = ['jg@altimos.de']
  spec.summary       = 'An experimental hypermedia REST client.'
  spec.description   = 'An experimental hypermedia REST client that uses parallel, keep-alive and pipelined requests by default.'
  spec.homepage      = 'https://github.com/jgraichen/restify'
  spec.license       = 'LGPLv3'

  spec.files         = Dir['**/*'].grep(%r{^((bin|lib|test|spec|features)/|.*\.gemspec|.*LICENSE.*|.*README.*|.*CHANGELOG.*)})
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'obligation', '~> 0.1'
  spec.add_runtime_dependency 'addressable', '~> 2.3'
  spec.add_runtime_dependency 'em-http-request', '~> 1.1'
  spec.add_runtime_dependency 'activesupport', '>= 3.2', '< 5'
  spec.add_runtime_dependency 'multi_json'
  spec.add_runtime_dependency 'rack'

  spec.add_development_dependency 'bundler', '~> 1.5'
end
