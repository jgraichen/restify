# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  subject(:resource) { Restify.new('http://localhost:9292/base').get.value! }

  before do
    stub_request(:get, 'http://stubserver/base')
      .to_return(
        status: 200,
        headers: {
          'Content-Type' => 'application/json',
          'Link' => '<http://localhost:9292/other>; rel="other"',
        },
        body:,
      )
  end

  describe 'Response bodies' do
    # #31: A content type is set, but the body is empty.
    context 'when empty' do
      let(:body) { '' }

      it 'returns a resource without data' do
        expect(resource.data).to be_nil
        expect(resource).to have_relation :other
      end
    end

    context 'when invalid' do
      let(:body) { '{"name": ' }

      it 'returns a resource with relations from headers' do
        expect(resource).to have_relation :other
      end

      it 'raises on accessing data' do
        expect { resource.data }.to raise_error(Restify::ParseError, /Could not parse response body/) do |error|
          expect(error.cause).to be_a JSON::ParserError
        end
      end
    end
  end
end
