# frozen_string_literal: true

require 'spec_helper'

describe Restify::ResponseError do
  let(:response) { double 'response' }
  let(:message) { 'Error' }
  let(:uri) { 'http://localhost' }

  before do
    allow(response).to receive(:uri).and_return(uri)
    allow(response).to receive(:code).and_return(code)
    allow(response).to receive(:message).and_return(message)
    allow(response).to receive(:decoded_body).and_return({})
  end


  describe '.from_code' do
    subject(:err) { described_class.from_code(response) }

    context 'with 400 Bad Request' do
      let(:code) { 400 }
      it { is_expected.to be_a ::Restify::BadRequest }
    end

    context 'with 401 Unauthorized' do
      let(:code) { 401 }
      it { is_expected.to be_a ::Restify::Unauthorized }
    end

    context 'with 404 Unauthorized' do
      let(:code) { 404 }
      it { is_expected.to be_a ::Restify::NotFound }
    end

    context 'with 406 Not Acceptable' do
      let(:code) { 406 }
      it { is_expected.to be_a ::Restify::NotAcceptable }
    end

    context 'with 410 Gone' do
      let(:code) { 410 }
      it { is_expected.to be_a ::Restify::Gone }
    end

    context 'with 422 Unprocessable Entity' do
      let(:code) { 422 }
      it { is_expected.to be_a ::Restify::UnprocessableEntity }
    end

    context 'with 500 Internal Server Error' do
      let(:code) { 500 }
      it { is_expected.to be_a ::Restify::InternalServerError }
    end

    context 'with 502 Bad Gateway' do
      let(:code) { 502 }
      it { is_expected.to be_a ::Restify::BadGateway }
    end

    context 'with 503 Service Unavailable' do
      let(:code) { 503 }
      it { is_expected.to be_a ::Restify::ServiceUnavailable }
    end

    context 'with 504 Gateway Timeout' do
      let(:code) { 504 }
      it { is_expected.to be_a ::Restify::GatewayTimeout }
    end
  end
end
