# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon do
  describe 'completed transfers' do
    subject(:value) do
      Restify::Promise.create do |writer|
        described_class.new.send(
          :complete,
          easy,
          request,
          writer,
        )
      end.value!
    end

    let(:request) { Restify::Request.new(uri: 'http://example.org/base') }
    let(:return_code) { :ok }
    let(:response_code) { 200 }

    # A transfer is handed back from libcurl with its return code and,
    # for HTTP, the status code of the response.
    def easy
      instance_double(
        described_class::Easy,
        return_code:,
        response_code:,
        response_headers: "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n",
        response_body: '{}',
      )
    end

    it 'fulfills the promise with the response' do
      expect(value.code).to eq 200
    end

    context 'when the transfer failed' do
      let(:return_code) { :couldnt_connect }
      let(:response_code) { 0 }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /connect/i
      end
    end

    # Non-HTTP protocols are refused before a transfer is started, but
    # libcurl still reports success with a zero status code whenever no
    # HTTP status was received, and no status code at all when it cannot
    # be read back. Neither has a response to process.
    context 'without an HTTP status' do
      let(:response_code) { 0 }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /without HTTP status/
      end
    end

    context 'with an unavailable HTTP status' do
      let(:response_code) { nil }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /without HTTP status/
      end
    end
  end
end
