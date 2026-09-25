# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon::Easy do
  let(:easy) { described_class.new }

  describe '#response' do
    subject(:response) { easy.response(request) }

    let(:request) { Restify::Request.new(uri: 'http://example.org/base') }

    # A transfer is handed back from libcurl with its return code and, for
    # HTTP, the status code of the response.
    let(:info) do
      {
        return_code: :ok,
        response_code: 200,
        effective_url: 'http://example.org/base',
        response_headers: "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n",
        response_body: '{}',
      }
    end

    before { allow(easy).to receive_messages(info) }

    it 'returns the response' do
      expect(response).to be_a Restify::Response
      expect(response).to have_attributes(code: 200, body: '{}', request:)
    end

    it 'reuses the request URI without redirects' do
      expect(response.uri).to be request.uri
    end

    context 'when redirected' do
      let(:info) { super().merge(effective_url: 'http://example.org/other/base') }

      it 'uses the effective URL as the response URI' do
        expect(response.uri.to_s).to eq 'http://example.org/other/base'
      end
    end

    context 'when the transfer failed' do
      let(:info) { super().merge(return_code: :couldnt_connect, response_code: 0) }

      it { expect { response }.to raise_error Restify::NetworkError, /connect/i }
    end

    # Non-HTTP protocols are refused before a transfer is started, but
    # libcurl still reports success with a zero status code whenever no
    # HTTP status was received, and no status code at all when it cannot
    # be read back. Neither has a response to process.
    context 'without an HTTP status' do
      let(:info) { super().merge(response_code: 0) }

      it { expect { response }.to raise_error Restify::NetworkError, /without HTTP status/ }
    end

    context 'with an unavailable HTTP status' do
      let(:info) { super().merge(response_code: nil) }

      it { expect { response }.to raise_error Restify::NetworkError, /without HTTP status/ }
    end

    describe 'headers' do
      subject(:headers) { response.headers }

      context 'with multiple values' do
        let(:info) { super().merge(response_headers: "HTTP/1.1 200 OK\r\nLink: <a>\r\nLink: <b>\r\n\r\n") }

        it { is_expected.to eq('LINK' => ['<a>', '<b>']) }
      end

      context 'with a folded value' do
        let(:info) { super().merge(response_headers: "HTTP/1.1 200 OK\r\nX-Long: first\r\n\tsecond\r\n\r\n") }

        it { is_expected.to eq('X_LONG' => 'first second') }
      end

      context 'with multiple responses, e.g. after a redirect' do
        let(:info) do
          super().merge(
            response_headers: "HTTP/1.1 302 Found\r\nLocation: /b\r\n\r\n" \
                              "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n",
          )
        end

        it { is_expected.to eq('CONTENT_TYPE' => 'text/plain') }
      end

      context 'without headers' do
        let(:info) { super().merge(response_headers: nil) }

        it { is_expected.to eq({}) }
      end
    end
  end

  describe '#reset' do
    it 'forgets the previous request' do
      easy._otel_span = Object.new
      easy._restify_request = Object.new
      easy._restify_writer = Object.new

      easy.reset

      expect([easy._otel_span, easy._restify_request, easy._restify_writer]).to all be_nil
    end
  end
end
