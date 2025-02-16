# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  subject(:echo) { resource.data }

  let(:resource) { Restify.new('http://localhost:9292/echo').get.value! }

  before do
    expect(OTLE_EXPORTER.finished_spans).to be_empty
  end

  describe 'OpenTelemetry' do
    it 'adds propagation header' do
      expect(echo).to have_key('HTTP_TRACEPARENT')
    end

    it 'adds spans' do
      resource

      spans = OTLE_EXPORTER.finished_spans
      expect(spans.size).to eq 2

      spans[1].tap do |span|
        expect(span.instrumentation_scope.name).to eq 'restify'
        expect(span.instrumentation_scope.version).to eq Restify::VERSION.to_s
        expect(span.attributes).to eq({
          'http.request.method' => 'GET',
          'http.response.status_code' => 200,
          'server.address' => 'localhost',
          'server.port' => 9292,
          'url.full' => 'http://localhost:9292/echo',
          'url.scheme' => 'http',
        })
      end

      # Latest span has to be from the Ethon instrumentation and must
      # have the Restify span as a parent.
      spans[0].tap do |span|
        expect(span.instrumentation_scope.name).to match(/Ethon/)
        expect(span.parent_span_id).to eq spans[1].span_id
      end
    end
  end
end
