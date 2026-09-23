# frozen_string_literal: true

require 'spec_helper'

describe Restify::Request do
  subject(:request) { described_class.new(uri:) }

  describe '#uri' do
    context 'with a string' do
      let(:uri) { 'https://example.org:8443/resources?page=2' }

      it 'parses it' do
        expect(request.uri).to be_a Addressable::URI
        expect(request.uri.to_s).to eq uri
      end
    end

    context 'with an Addressable::URI' do
      let(:uri) { Addressable::URI.parse('https://example.org/resources') }

      it 'keeps it as is' do
        expect(request.uri).to be uri
      end
    end
  end
end
