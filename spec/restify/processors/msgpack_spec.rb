# frozen_string_literal: true

require 'spec_helper'

describe Restify::Processors::Msgpack do
  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:response) { double 'response' }

  before do
    allow(response).to receive(:links).and_return []
    allow(response).to receive(:follow_location).and_return nil
  end

  describe 'class' do
    describe '#accept?' do
      subject { described_class.accept? response }

      it 'accepts msgpack mime type (I)' do
        expect(response).to receive(:content_type).and_return('application/msgpack')
        expect(subject).to be_truthy
      end

      it 'accepts msgpack mime type (II)' do
        expect(response).to receive(:content_type).and_return('application/msgpack; abc')
        expect(subject).to be_truthy
      end

      it 'accepts x-msgpack mime type (I)' do
        expect(response).to receive(:content_type).and_return('application/x-msgpack')
        expect(subject).to be_truthy
      end

      it 'accepts x-msgpack mime type (II)' do
        expect(response).to receive(:content_type).and_return('application/x-msgpack; abc')
        expect(subject).to be_truthy
      end
    end
  end

  describe '#resource' do
    subject { described_class.new(context, response).resource }

    before { allow(response).to receive(:body).and_return(body) }

    describe 'parsing' do
      context 'single object' do
        let(:body) do
          ::MessagePack.dump('msg' => 'value')
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(subject.response).to be response }
        it { is_expected.to eq 'msg' => 'value' }
      end

      context 'object with relation fields' do
        let(:body) do
          ::MessagePack.dump(
            'msg' => 'value',
            'search_url' => 'https://google.com{?q}',
          )
        end

        it do
          expect(subject).to eq \
            'msg' => 'value', 'search_url' => 'https://google.com{?q}'
        end

        it { is_expected.to have_relation :search }
        it { expect(subject.relation(:search)).to eq 'https://google.com{?q}' }
      end

      context 'object with implicit self relation' do
        let(:body) do
          ::MessagePack.dump(
            'url' => '/self',
          )
        end

        it { expect(subject.relation(:self)).to eq '/self' }
      end

      context 'single array' do
        let(:body) do
          ::MessagePack.dump([1, 2, nil, 'STR'])
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(subject.response).to be response }
        it { is_expected.to eq [1, 2, nil, 'STR'] }
      end

      context 'array with objects' do
        let(:body) do
          ::MessagePack.dump([{'a' => 0}, {'b' => 1}])
        end

        it { is_expected.to eq [{'a' => 0}, {'b' => 1}] }
      end

      context 'array with resources' do
        let(:body) do
          ::MessagePack.dump([
            {'name' => 'John', 'self_url' => '/users/john'},
            {'name' => 'Jane', 'self_url' => '/users/jane'},
          ])
        end

        it 'parses objects as resources' do
          expect(subject).to all(be_a(Restify::Resource))
        end

        it 'parses relations of resources' do
          expect(subject.map {|r| r.relation :self }).to eq \
            ['/users/john', '/users/jane']
        end
      end

      context 'nested objects' do
        let(:body) do
          ::MessagePack.dump(
            'john' => {'name' => 'John'},
            'jane' => {'name' => 'Jane'},
          )
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(subject.response).to be response }

        it 'parses objects as resources' do
          expect(subject['john']).to be_a Restify::Resource
          expect(subject['jane']).to be_a Restify::Resource

          expect(subject['john']['name']).to eq 'John'
          expect(subject['jane']['name']).to eq 'Jane'
        end
      end

      context 'single value' do
        let(:body) do
          ::MessagePack.dump('BLUB')
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(subject.response).to be response }
        it { is_expected.to eq 'BLUB' }
      end

      context 'with indifferent access' do
        let(:body) do
          ::MessagePack.dump('name' => 'John', 'age' => 24)
        end

        it '#key?' do
          expect(subject).to have_key 'name'
          expect(subject).to have_key 'age'

          expect(subject).to have_key :name
          expect(subject).to have_key :age
        end

        it '#[]' do
          expect(subject['name']).to eq 'John'
          expect(subject['age']).to eq 24

          expect(subject[:name]).to eq 'John'
          expect(subject[:age]).to eq 24
        end
      end

      context 'with method getter access' do
        let(:body) do
          ::MessagePack.dump('name' => 'John', 'age' => 24)
        end

        it '#<method getter>' do
          expect(subject).to respond_to :name
          expect(subject).to respond_to :age

          expect(subject.name).to eq 'John'
          expect(subject.age).to eq 24
        end
      end
    end
  end
end
