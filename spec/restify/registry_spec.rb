# frozen_string_literal: true

require 'spec_helper'

describe Restify::Registry do
  subject(:registry) { described_class.instance }

  describe 'class' do
    describe '#instance' do
      it 'returns singleton instance' do
        expect(registry).to be_a described_class
        expect(registry).to be described_class.instance
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
    subject(:store) { registry.store(name, uri, **opts) }

    let(:name) { 'remote' }
    let(:uri)  { 'http://remote/entry/point' }
    let(:opts) { {accept: 'application/vnd.remote+json'} }

    it 'stores registry item' do
      store

      item = registry.fetch name

      expect(item.uri.to_s).to eq uri
      expect(item.options).to eq opts
    end
  end
end
