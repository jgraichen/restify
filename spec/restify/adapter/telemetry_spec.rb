# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Telemetry do
  subject(:call) { adapter.call(request).value! }

  let(:adapter) do
    Class.new(Restify::Adapter::Base) do
      def call_native(request, writer)
        writer.fulfill(Restify::Response.new(request, request.uri, 200, {}, ''))
      end
    end.new
  end

  let(:request) { Restify::Request.new(uri:) }
  let(:span) { OTLE_EXPORTER.finished_spans.last }

  before { call }

  context 'with an explicit port' do
    let(:uri) { Addressable::URI.parse('https://example.org:8443/resources') }

    it 'records the given port' do
      expect(span.name).to eq 'GET https://example.org:8443'
      expect(span.attributes).to eq({
        'http.request.method' => 'GET',
        'http.response.status_code' => 200,
        'server.address' => 'example.org',
        'server.port' => 8443,
        'url.full' => 'https://example.org:8443/resources',
        'url.scheme' => 'https',
      })
    end
  end

  context 'without a port' do
    let(:uri) { Addressable::URI.parse('https://example.org/resources') }

    it 'records the default port of the scheme' do
      expect(span.name).to eq 'GET https://example.org:443'
      expect(span.attributes).to include(
        'server.port' => 443,
        'url.full' => 'https://example.org/resources',
      )
    end
  end

  context 'with a URI given as a string' do
    let(:uri) { 'http://example.org/resources' }

    it 'parses it' do
      expect(span.name).to eq 'GET http://example.org:80'
      expect(span.attributes).to include(
        'server.address' => 'example.org',
        'server.port' => 80,
        'url.full' => 'http://example.org/resources',
      )
    end
  end
end
