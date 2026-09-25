# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

describe Restify::Context do
  let(:uri) { 'http://localhost' }
  let(:kwargs) { {} }
  let(:context) { Restify::Context.new(uri, **kwargs) }

  describe '<serialization>' do
    shared_examples 'serialization' do
      describe '#uri' do
        subject { super().uri }

        it { is_expected.to be_a Addressable::URI }
        it { is_expected.to eq context.uri }
      end

      describe '#adapter' do
        subject { super().options[:adapter] }

        let(:kwargs) { {adapter: instance_double(Restify::Adapter::Base)} }

        it 'adapter is not serialized' do
          expect(subject).to equal nil
        end
      end

      describe '#cache' do
        subject { super().options[:cache] }

        let(:kwargs) { {cache: Object.new} }

        it 'cache is not serialized' do
          expect(subject).to equal nil
        end
      end

      describe '#headers' do
        subject { super().options[:headers] }

        let(:kwargs) { {headers: {'Accept' => 'application/json'}} }

        it 'all headers are serialized' do
          expect(subject).to eq('Accept' => 'application/json')
        end
      end
    end

    context 'YAML' do
      subject { load }

      let(:dump) { YAML.dump(context) }

      if RUBY_VERSION >= '3.1'
        let(:load) { YAML.safe_load(dump, permitted_classes: [Restify::Context, Symbol]) }
      else
        let(:load) { YAML.load(dump) }
      end

      it_behaves_like 'serialization'
    end

    context 'Marshall' do
      subject { load }

      let(:dump) { Marshal.dump(context) }
      let(:load) { Marshal.load(dump) } # rubocop:disable Security/MarshalLoad

      it_behaves_like 'serialization'
    end
  end

  describe '#request' do
    subject(:request) { context.request(:get, '/').value! }

    let(:adapter) do
      response = Restify::Response.new(nil, Addressable::URI.parse(uri), 200, {}, 'body')

      instance_double(Restify::Adapter::Base).tap do |adapter|
        allow(adapter).to receive(:call).and_return(Restify::Promise.fulfilled(response))
      end
    end

    let(:cache) do
      Object.new.tap do |cache|
        def cache.call(request)
          yield(request)
        end
      end
    end

    let(:kwargs) { {adapter:} }

    it 'calls the adapter without a cache' do
      expect(adapter).to receive(:call).with(Restify::Request)

      request
    end

    context 'with a cache' do
      let(:kwargs) { {adapter:, cache:} }

      it 'lets the cache call the adapter' do
        expect(cache).to receive(:call).with(Restify::Request).and_call_original
        expect(adapter).to receive(:call).with(Restify::Request)

        request
      end
    end

    context 'with a global cache' do
      around do |example|
        Restify.cache = cache
        example.run
      ensure
        Restify.cache = nil
      end

      it 'lets the cache call the adapter' do
        expect(cache).to receive(:call).with(Restify::Request).and_call_original
        expect(adapter).to receive(:call).with(Restify::Request)

        request
      end
    end
  end
end
