# frozen_string_literal: true

require 'opentelemetry'
require 'opentelemetry/common'

module Restify
  module Adapter
    module Telemetry
      def call(request)
        method = request.method.to_s.upcase
        uri = URI.parse(request.uri)
        name = "#{method} #{uri.scheme}://#{uri.host}:#{uri.port}"

        attributes = {
          'http.request.method' => method,
          'server.address' => uri.host,
          'server.port' => uri.port,
          'url.full' => uri.to_s,
          'url.scheme' => uri.scheme,
        }

        span = tracer.start_span(name, attributes:, kind: :client)
        OpenTelemetry::Trace.with_span(span) do
          OpenTelemetry.propagation.inject(request.headers)

          super.tap do |x|
            x.add_observer do |_, response, err|
              if response
                span.set_attribute('http.response.status_code', response&.code)
                span.status = OpenTelemetry::Trace::Status.error unless (100..399).cover?(response&.code)
              end

              span.status = OpenTelemetry::Trace::Status.error(err) if err

              span.finish
            end
          end
        end
      end

      protected

      def tracer
        Telemetry.tracer
      end

      class << self
        def tracer
          @tracer ||= OpenTelemetry.tracer_provider.tracer('restify', Restify::VERSION.to_s)
        end
      end
    end
  end
end
