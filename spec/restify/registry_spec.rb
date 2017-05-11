# frozen_string_literal: true

require 'spec_helper'

describe Restify::Registry do
  let(:registry) { described_class.instance }

  describe 'class' do
    describe '#instance' do
      subject { described_class.instance }

      it 'returns singleton instance' do
        expect(subject).to be_a described_class
        expect(subject).to be described_class.instance
      end
    end

    describe '#fetch' do
      it 'delegates to singleton instance' do
        args = Object.new
        expect(described_class.instance).to receive(:fetch).with(args)

        described_class.fetch args
      end
    end

    describe '#store' do
      it 'delegates to singleton instance' do
        arg1 = Object.new
        arg2 = Object.new
        expect(described_class.instance).to receive(:store).with(arg1, arg2)

        described_class.store arg1, arg2
      end
    end
  end

  describe '#store / #fetch' do
    let(:name) { 'remote' }
    let(:uri)  { 'http://remote/entry/point' }
    let(:opts) { {accept: 'application/vnd.remote+json'} }

    subject { registry.store name, uri, **opts }

    it 'stores registry item' do
      subject

      item = registry.fetch name

      expect(item.uri.to_s).to eq uri
      expect(item.options).to eq opts
    end
  end
end
