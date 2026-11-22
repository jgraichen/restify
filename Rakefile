# frozen_string_literal: true

require 'rake/release/task'

Rake::Release::Task.new do |spec|
  spec.sign_tag = true

  # Tag pre-releases as SemVer (`v3.0.0-rc4`), as required for creating
  # the GitHub release, while the gem version stays `3.0.0.rc4`.
  spec.version_tag = "v#{spec.version.to_s.sub(/\.(?=[a-z])/i, '-')}"
end

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError # rubocop:disable Lint/SuppressedException
end

begin
  require 'yard'
  require 'yard/rake/yardoc_task'

  YARD::Rake::YardocTask.new do |t|
    t.files = %w[lib/**/*.rb]
    t.options = %w[--output-dir doc/]
  end
rescue LoadError # rubocop:disable Lint/SuppressedException
end
