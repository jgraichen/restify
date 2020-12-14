# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:post, 'http://localhost/base')
      .to_return do
      <<-RESPONSE.gsub(/^ {8}/, '')
        HTTP/1.1 200 OK
        Content-Length: 333
        Transfer-Encoding: chunked
        Link: <http://localhost/other>; rel="neat"
      RESPONSE
    end
  end

  describe 'Request body' do
    subject { Restify.new('http://localhost/base').post(body, {}, {headers: headers}).value! }
    let(:headers) { {} }

    context 'with JSON-like data structures' do
      let(:body) { {a: 'b', c: 'd'} }

      it 'is serialized as JSON' do
        subject

        expect(
          request_stub.with(body: '{"a":"b","c":"d"}')
        ).to have_been_requested
      end

      it 'gets a JSON media type for free' do
        subject

        expect(
          request_stub.with(headers: {'Content-Type' => 'application/json'})
        ).to have_been_requested
      end
    end

    context 'with strings' do
      let(:body) { 'a=b&c=d' }

      it 'is sent as provided' do
        subject

        expect(
          request_stub.with(body: 'a=b&c=d')
        ).to have_been_requested
      end

      it 'does not get a JSON media type' do
        subject

        expect(
          request_stub.with {|req| req.headers['Content-Type'].nil? }
        ).to have_been_requested
      end
    end
  end
end
