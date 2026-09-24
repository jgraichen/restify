# frozen_string_literal: true

# Compare how much memory adapters allocate.
#
# Usage:
#
#     bundle exec ruby benchmark/allocations.rb
#
# Environment variables:
#
#     ADAPTERS   Comma-separated adapters to compare
#                (default: ethon,typhoeus,typhoeus-sync)
#     LOG_LEVEL  Restify log level (default: warn)
#
require 'benchmark/memory'

require_relative 'support/scenarios'

Bench.run do |name, scenario, clients|
  puts "\n== Allocations: #{name} ==\n\n"

  Benchmark.memory do |x|
    clients.each do |adapter, root|
      x.report(adapter) { scenario.call(root) }
    end

    x.compare!
  end
end
