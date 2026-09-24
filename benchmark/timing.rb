# frozen_string_literal: true

# Compare the throughput of adapters.
#
# Usage:
#
#     bundle exec ruby benchmark/timing.rb
#
# Environment variables:
#
#     ADAPTERS   Comma-separated adapters to compare
#                (default: ethon,typhoeus,typhoeus-sync)
#     WARMUP     Warmup seconds per report (default: 2)
#     TIME       Measurement seconds per report (default: 10)
#     LOG_LEVEL  Restify log level (default: warn)
#
require 'benchmark/ips'

require_relative 'support/scenarios'

WARMUP = Float(ENV.fetch('WARMUP', 2))
TIME   = Float(ENV.fetch('TIME', 10))

Bench.run do |name, scenario, clients|
  puts "\n== Timing: #{name} ==\n\n"

  Benchmark.ips do |x|
    x.warmup = WARMUP
    x.time   = TIME

    clients.each do |adapter, root|
      x.report(adapter) { scenario.call(root) }
    end

    x.compare!
  end
end
