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
        let(:kwargs) { {adapter: double('adapter')} }
        subject { super().options[:adapter] }

        it 'adapter is not serialized' do
          expect(subject).to equal nil
        end
      end

      describe '#cache' do
        let(:kwargs) { {adapter: double('cache')} }
        subject { super().options[:cache] }

        it 'cache is not serialized' do
          expect(subject).to equal nil
        end
      end

      describe '#headers' do
        let(:kwargs) { {headers: {'Accept' => 'application/json'}} }
        subject { super().options[:headers] }

        it 'all headers are serialized' do
          expect(subject).to eq({'Accept' => 'application/json'})
        end
      end
    end

    context 'YAML' do
      let(:dump) { YAML.dump(context) }
      let(:load) { YAML.load(dump) } # rubocop:disable YAMLLoad

      subject { load }

      include_examples 'serialization'
    end

    context 'Marshall' do
      let(:dump) { Marshal.dump(context) }
      let(:load) { Marshal.load(dump) } # rubocop:disable MarshalLoad

      subject { load }

      include_examples 'serialization'
    end
  end
end
