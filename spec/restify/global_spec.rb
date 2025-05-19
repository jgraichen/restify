# frozen_string_literal: true

require 'spec_helper'

describe Restify::Global do
  let(:global) { Restify }

  describe '#new' do
    context 'with string URI' do
      subject(:restify) { global.new(uri, **options) }

      let(:uri)     { 'http://api.github.com/' }
      let(:options) { {accept: 'application.vnd.github.v3+json'} }

      it 'returns relation for URI' do
        expect(restify).to be_a Restify::Relation
        expect(restify.pattern).to eq uri
        expect(restify.context.uri.to_s).to eq uri
        expect(restify.context.options).to eq options
      end
    end

    context 'with registry symbol' do
      subject(:restify) { global.new(name, **options) }

      let(:name) { :registry_item_name }
      let(:uri)     { 'http://api.github.com/' }
      let(:options) { {accept: 'application.vnd.github.v3+json'} }
      let(:context) { Restify::Context.new uri, **options }

      it 'returns relation for stored registry item' do
        Restify::Registry.store(name, uri, **options)

        expect(restify).to be_a Restify::Relation
        expect(restify.pattern).to eq uri
        expect(restify.context.uri.to_s).to eq uri
        expect(restify.context.options).to eq options
      end
    end
  end

  describe '#adapter' do
    subject(:adapter) { global.adapter }

    it 'defaults to Typhoeus adapter' do
      expect(adapter).to be_a Restify::Adapter::Typhoeus
    end
  end

  describe '#adapter=' do
    let(:stub) { Object.new }

    # Ensure to reset adapter after these specs!
    after { Restify.adapter = nil }

    it 'sets a new adapter' do
      global.adapter = stub
      expect(global.adapter).to be stub
    end
  end

  describe '#cache' do
    subject(:cache) { global.cache }

    it 'defaults to Typhoeus adapter' do
      expect(cache).to be_a Restify::Cache
    end
  end

  describe '#cache=' do
    let(:stub) { Object.new }

    # Ensure to reset cache after these specs!
    after { Restify.cache = nil }

    it 'sets a new adapter' do
      global.cache = stub
      expect(global.cache).to be stub
    end
  end

  describe '#logger' do
    subject(:logger) { global.logger }

    it 'returns Restify root logger' do
      expect(logger).to be_a Logging::Logger
      expect(logger).to eq Logging.logger[Restify]
    end
  end
end
