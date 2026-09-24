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

    around do |example|
      Restify.adapter.tap do |configured|
        Restify.adapter = nil
        example.run
      ensure
        Restify.adapter = configured
      end
    end

    it 'defaults to Ethon adapter' do
      expect(adapter).to be_a Restify::Adapter::Ethon
    end
  end

  describe '#adapter=' do
    let(:stub) { Object.new }

    # Ensure to restore the configured adapter after these specs!
    around do |example|
      Restify.adapter.tap do |configured|
        Restify.adapter = nil
        example.run
      ensure
        Restify.adapter = configured
      end
    end

    it 'sets a new adapter' do
      global.adapter = stub
      expect(global.adapter).to be stub
    end
  end

  describe '#cache' do
    subject(:cache) { global.cache }

    it 'defaults to cache instance' do
      expect(cache).to be_a Restify::Cache
    end
  end

  describe '#cache=' do
    let(:stub) { Object.new }

    # Ensure to reset cache after these specs!
    after { Restify.cache = nil }

    it 'sets a new cache' do
      global.cache = stub
      expect(global.cache).to be stub
    end
  end

  describe '#logger' do
    subject(:logger) { global.logger }

    around do |example|
      global.logger.tap do |configured|
        global.logger = nil
        example.run
      ensure
        global.logger = configured
      end
    end

    it 'is not set by default' do
      expect(logger).to be_nil
    end

    it 'does not log anything without a logger' do
      loggable = Class.new { include Restify::Logging }.new

      expect { loggable.debug('message') }.not_to output.to_stdout_from_any_process
      expect { loggable.error(RuntimeError.new('kaboom')) }.not_to output.to_stderr_from_any_process
    end
  end

  describe '#logger=' do
    let(:configured) { Logger.new(nil) }

    around do |example|
      global.logger.tap do |previous|
        example.run
      ensure
        global.logger = previous
      end
    end

    it 'sets the logger' do
      global.logger = configured

      expect(global.logger).to be configured
    end

    it 'is used for messages from Restify' do
      output = StringIO.new
      global.logger = Logger.new(output, level: :debug)

      Class.new { include Restify::Logging }.new.debug('message', key: 'value')

      expect(output.string).to include 'message key=value'
    end

    it 'is used for errors from Restify' do
      output = StringIO.new
      global.logger = Logger.new(output)

      stub_const('Loggable', Class.new { include Restify::Logging })
      Loggable.new.error(RuntimeError.new('kaboom'))

      expect(output.string).to include 'ERROR -- Loggable: kaboom (RuntimeError)'
    end
  end
end
