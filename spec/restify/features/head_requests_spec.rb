# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:head, 'http://localhost/base')
      .with(query: hash_including({}))
      .to_return do
      <<-RESPONSE.gsub(/^ {8}/, '')
        HTTP/1.1 200 OK
        Content-Length: 333
        Transfer-Encoding: chunked
        Link: <http://localhost/other>; rel="neat"
      RESPONSE
    end
  end

  describe 'HEAD requests' do
    subject { Restify.new('http://localhost/base').head(params).value! }
    let(:params) { {} }

    it 'returns a resource with access to headers' do
      expect(subject.response.headers).to include('CONTENT_LENGTH' => '333')
    end

    it 'parses Link headers into relations' do
      expect(subject).to have_relation :neat
    end

    context 'with params' do
      let(:params) { {foo: 'bar'} }

      it 'adds them to the query string' do
        subject
        expect(
          request_stub.with(query: {foo: 'bar'})
        ).to have_been_requested
      end
    end
  end
end
