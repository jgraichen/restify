# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/ethon'

OTLE_EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(OTLE_EXPORTER)

OpenTelemetry::SDK.configure do |c|
  c.error_handler = ->(exception:, message:) { raise(exception || message) }
  c.logger = Logger.new($stderr, level: ENV.fetch('OTEL_LOG_LEVEL', 'fatal').to_sym)
  c.add_span_processor span_processor

  c.use 'OpenTelemetry::Instrumentation::Ethon'
end

RSpec.configure do |config|
  config.around do |example|
    OTLE_EXPORTER.reset

    original_propagation = OpenTelemetry.propagation
    propagator = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator
    OpenTelemetry.propagation = propagator

    example.run
  ensure
    OpenTelemetry.propagation = original_propagation
  end
end
