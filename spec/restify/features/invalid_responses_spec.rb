# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  before do
    stub_request(:get, 'http://stubserver/base')
      .to_return(status: http_status, headers: headers, body: body)
  end

  let(:http_status) { '200 OK' }
  let(:headers) { {} }
  let(:body) { '' }

  describe 'Invalid server responses' do
    subject(:request) { Restify.new('http://localhost:9292/base').get.value! }

    describe 'Empty JSON response' do
      let(:headers) do
        {
          'Content-Type' => 'application/json',
          'Link' => '<http://localhost:9292/other>; rel="next"',
        }
      end
      let(:body) { '' }

      it 'does not raise any error when completing the request' do
        expect { request }.not_to raise_error
      end

      it 'errors when trying to access the decoded response body' do
        expect { request.data }.to raise_error(JSON::ParserError)
      end

      it 'ignores parsing errors when trying to access relations expected in the body' do
        expect(request.rel?(:child)).to be false
        expect { request.rel(:body) }.to raise_error(KeyError)
      end

      it 'still returns relations from response headers' do
        expect(request.rel?(:next)).to be true
        expect(request.rel(:next)).to be_a Restify::Relation
      end
    end
  end
end
