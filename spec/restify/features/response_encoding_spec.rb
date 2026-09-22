# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  describe 'Response body encoding' do
    subject(:response) { Restify.new('http://localhost:9292/base').get.value!.response }

    let(:text) { 'Grüße, Ærø – 日本' }

    before do
      stub_request(:get, 'http://stubserver/base').to_return(
        status: 200,
        headers: {'Content-Type' => content_type},
        body: body,
      )
    end

    context 'with an UTF-8 charset' do
      let(:content_type) { 'text/plain; charset=UTF-8' }
      let(:body) { text.encode(Encoding::UTF_8) }

      it 'returns the body in the given encoding' do
        expect(response.body.encoding).to eq Encoding::UTF_8
        expect(response.body).to eq text
      end
    end

    context 'with an ISO-8859-1 charset' do
      let(:content_type) { 'text/plain; charset=ISO-8859-1' }
      let(:text) { 'Grüße, Ærø' }
      let(:body) { text.encode(Encoding::ISO_8859_1) }

      it 'returns the body in the given encoding' do
        expect(response.body.encoding).to eq Encoding::ISO_8859_1
        expect(response.body).to eq text.encode(Encoding::ISO_8859_1)
        expect(response.body.encode(Encoding::UTF_8)).to eq text
      end
    end

    context 'with a quoted charset' do
      let(:content_type) { 'text/plain; charset="utf-8"' }
      let(:body) { text.encode(Encoding::UTF_8) }

      it 'returns the body in the given encoding' do
        expect(response.body.encoding).to eq Encoding::UTF_8
        expect(response.body).to eq text
      end
    end

    context 'with an unknown charset' do
      let(:content_type) { 'text/plain; charset=nonsense' }
      let(:body) { text.encode(Encoding::UTF_8) }

      it 'returns the body as binary' do
        expect(response.body.encoding).to eq Encoding::BINARY
        expect(response.body.b).to eq text.b
      end
    end

    context 'without a charset' do
      let(:content_type) { 'text/plain' }
      let(:body) { text.encode(Encoding::UTF_8) }

      it 'returns the body as binary' do
        expect(response.body.encoding).to eq Encoding::BINARY
        expect(response.body.b).to eq text.b
      end
    end

    context 'with a JSON body' do
      let(:content_type) { 'application/json; charset=ISO-8859-1' }
      let(:text) { 'Grüße, Ærø' }
      let(:body) { %("#{text}").encode(Encoding::ISO_8859_1) }

      it 'decodes the body using the given encoding' do
        expect(response.body.encoding).to eq Encoding::ISO_8859_1
        expect(response.decoded_body).to eq text
      end
    end
  end
end
