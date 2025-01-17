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

      include_examples 'serialization'
    end

    context 'Marshall' do
      subject { load }

      let(:dump) { Marshal.dump(context) }
      let(:load) { Marshal.load(dump) } # rubocop:disable Security/MarshalLoad

      include_examples 'serialization'
    end
  end
end
