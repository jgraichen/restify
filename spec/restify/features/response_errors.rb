# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:get, 'http://localhost/base')
      .to_return do
      <<-RESPONSE.gsub(/^ {8}/, '')
        HTTP/1.1 #{http_status}
        Content-Length: 333
        Transfer-Encoding: chunked
        Link: <http://localhost/other>; rel="neat"
      RESPONSE
    end
  end

  let(:http_status) { '200 OK' }

  describe 'Error handling' do
    subject(:request) { Restify.new('http://localhost/base').get.value! }

    context 'for 400 status codes' do
      let(:http_status) { '400 Bad Request' }

      it 'throws a BadRequest exception' do
        expect { request }.to raise_error Restify::BadRequest
      end
    end

    context 'for 401 status codes' do
      let(:http_status) { '401 Unauthorized' }

      it 'throws an Unauthorized exception' do
        expect { request }.to raise_error Restify::Unauthorized
      end
    end

    context 'for 404 status codes' do
      let(:http_status) { '404 Not Found' }

      it 'throws a ClientError exception' do
        expect { request }.to raise_error Restify::NotFoundError
      end
    end

    context 'for 406 status codes' do
      let(:http_status) { '406 Not Acceptable' }

      it 'throws a NotAcceptable exception' do
        expect { request }.to raise_error Restify::NotAcceptable
      end
    end

    context 'for 422 status codes' do
      let(:http_status) { '422 Unprocessable Entity' }

      it 'throws a UnprocessableEntity exception' do
        expect { request }.to raise_error Restify::UnprocessableEntity
      end
    end

    context 'for any other 4xx status codes' do
      let(:http_status) { '415 Unsupported Media Type' }

      it 'throws a generic ClientError exception' do
        expect { request }.to raise_error Restify::ClientError
      end
    end

    context 'for any 5xx status codes' do
      let(:http_status) { '500 Internal Server Error' }

      it 'throws a generic ServerError exception' do
        expect { request }.to raise_error Restify::ServerError
      end
    end
  end
end