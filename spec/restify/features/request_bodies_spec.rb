# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:post, 'http://stubserver/base').to_return do
      <<~HTTP
        HTTP/1.1 200 OK
        Link: <http://localhost:9292/other>; rel="neat"
      HTTP
    end
  end

  describe 'Request body' do
    subject { Restify.new('http://localhost:9292/base').post(body, {}, {headers: headers}).value! }

    let(:headers) { {} }

    context 'with JSON-like data structures' do
      let(:body) { {a: 'b', c: 'd'} }

      it 'is serialized as JSON' do
        subject

        expect(
          request_stub.with(body: '{"a":"b","c":"d"}'),
        ).to have_been_requested
      end

      it 'gets a JSON media type for free' do
        subject

        expect(
          request_stub.with(headers: {'Content-Type' => 'application/json'}),
        ).to have_been_requested
      end

      context 'with overridden media type' do
        let(:headers) { {'Content-Type' => 'application/vnd.api+json'} }

        it 'respects the override' do
          subject

          expect(
            request_stub.with(headers: {'Content-Type' => 'application/vnd.api+json'}),
          ).to have_been_requested
        end
      end
    end

    context 'with strings' do
      let(:body) { 'a=b&c=d' }

      it 'is sent as provided' do
        subject

        expect(
          request_stub.with(body: 'a=b&c=d'),
        ).to have_been_requested
      end

      it 'does not get a JSON media type' do
        subject

        expect(
          request_stub.with {|req| req.headers['Content-Type'] !~ /json/ },
        ).to have_been_requested
      end

      context 'with overridden media type' do
        let(:headers) { {'Content-Type' => 'application/text'} }

        it 'respects the override' do
          subject

          expect(
            request_stub.with(headers: {'Content-Type' => 'application/text'}),
          ).to have_been_requested
        end
      end
    end
  end
end
