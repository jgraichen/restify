# frozen_string_literal: true

require 'spec_helper'

describe Restify::Processors::Json do
  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:response) { instance_double(Restify::Response) }

  before do
    allow(response).to receive_messages(links: [], follow_location: nil)
  end

  describe 'class' do
    describe '#accept?' do
      subject(:accept) { described_class.accept?(response) }

      it 'accepts JSON mime type (I)' do
        allow(response).to receive(:content_type).and_return('application/json')
        expect(accept).to be_truthy
      end

      it 'accepts JSON mime type (II)' do
        allow(response).to receive(:content_type).and_return('application/json; abc')
        expect(accept).to be_truthy
      end
    end
  end

  describe '#resource' do
    subject(:resource) { described_class.new(context, response).resource }

    before { allow(response).to receive(:body).and_return(body) }

    describe 'parsing' do
      context 'single object' do
        let(:body) do
          <<-JSON
            {"json": "value"}
          JSON
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(resource.response).to be response }
        it { is_expected.to eq 'json' => 'value' }
      end

      context 'object with relation fields' do
        let(:body) do
          <<-JSON
            {"json": "value", "search_url": "https://google.com{?q}"}
          JSON
        end

        it do
          expect(resource).to eq \
            'json' => 'value', 'search_url' => 'https://google.com{?q}'
        end

        it { is_expected.to have_relation :search }
        it { expect(resource.relation(:search)).to eq 'https://google.com{?q}' }
      end

      context 'object with implicit self relation' do
        let(:body) do
          <<-JSON
            {"json": "value", "url": "/self"}
          JSON
        end

        it { expect(resource.relation(:self)).to eq '/self' }
      end

      context 'single array' do
        let(:body) do
          <<-JSON
            [1, 2, null, "STR"]
          JSON
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(resource.response).to be response }
        it { is_expected.to eq [1, 2, nil, 'STR'] }
      end

      context 'array with objects' do
        let(:body) do
          <<-JSON
            [{"a":0}, {"b":1}]
          JSON
        end

        it { is_expected.to eq [{'a' => 0}, {'b' => 1}] }
      end

      context 'array with resources' do
        let(:body) do
          <<-JSON
            [{"name": "John", "self_url": "/users/john"},
             {"name": "Jane", "self_url": "/users/jane"}]
          JSON
        end

        it 'parses objects as resources' do
          expect(resource).to all(be_a(Restify::Resource))
        end

        it 'parses relations of resources' do
          expect(resource.map {|r| r.relation :self }).to eq \
            ['/users/john', '/users/jane']
        end
      end

      context 'nested objects' do
        let(:body) do
          <<-JSON
            {"john": {"name": "John"},
             "jane": {"name": "Jane"}}
          JSON
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(resource.response).to be response }

        it 'parses objects as resources' do
          expect(resource['john']).to be_a Restify::Resource
          expect(resource['jane']).to be_a Restify::Resource

          expect(resource['john']['name']).to eq 'John'
          expect(resource['jane']['name']).to eq 'Jane'
        end
      end

      context 'single value' do
        let(:body) do
          <<-JSON
            "BLUB"
          JSON
        end

        it { is_expected.to be_a Restify::Resource }
        it { expect(resource.response).to be response }
        it { is_expected.to eq 'BLUB' }
      end
    end
  end
end
