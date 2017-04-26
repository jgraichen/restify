# frozen_string_literal: true
require 'spec_helper'

describe Restify::Processors::Base do
  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:response) { double 'response' }

  before do
    allow(response).to receive(:links).and_return []
    allow(response).to receive(:follow_location).and_return nil
  end

  describe 'class' do
    describe '#accept?' do
      subject { described_class.accept? response }

      # If no other processor accepts the request, we have an explicit fallback
      # to the base processor.
      it 'does not accept any responses' do
        expect(subject).to be_falsey
      end
    end
  end

  describe '#resource' do
    subject { described_class.new(context, response).resource }
    before { allow(response).to receive(:body).and_return(body) }

    describe 'parsing' do
      context 'string' do
        let(:body) do
          <<-BODY
            binaryblob
          BODY
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(subject.response).to be response }
        it { is_expected.to eq body }
      end
    end
  end
end
