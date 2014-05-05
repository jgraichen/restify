# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'restify/version'

Gem::Specification.new do |spec|
  spec.name          = 'restify'
  spec.version       = Restify::VERSION
  spec.authors       = ['Jan Graichen']
  spec.email         = ['jg@altimos.de']
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = 'https://github.com/jgraichen/restify'
  spec.license       = 'LGPLv3'

  spec.files         = Dir['**/*'].grep(%r{^((bin|lib|test|spec|features)/|.*\.gemspec|.*LICENSE.*|.*README.*|.*CHANGELOG.*)})
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.5'
end
