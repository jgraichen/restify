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

    describe 'empty body' do
      let(:body) { '' }

      it { is_expected.to be_a Restify::Resource }
      it { expect(resource.data).to be_nil }
    end

    describe 'invalid body' do
      let(:body) { '{"json": ' }

      before do
        allow(response).to receive_messages(
          uri: Addressable::URI.parse('http://test.host/'),
          links: Restify::Link.parse('<http://test.host/other>; rel="other"'),
        )
      end

      it { is_expected.to be_a Restify::Resource }
      it { is_expected.to have_relation :other }
      it { expect(resource.response).to be response }

      it 'raises on accessing data' do
        expect { resource.data }.to raise_error(Restify::ParseError) do |error|
          expect(error.response).to be response
          expect(error.cause).to be_a JSON::ParserError
        end
      end

      it 'raises on accessing delegated data' do
        expect { resource['json'] }.to raise_error Restify::ParseError
      end

      it { is_expected.not_to respond_to :each }
      it { expect(resource.inspect).to include '@error=' }
    end

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

      context 'relation fields with relative references' do
        let(:context) { Restify::Context.new('http://test.host/users/42') }
        let(:body) do
          <<-JSON
            {"items_url": "items", "status_url": "none"}
          JSON
        end

        it 'resolves them against the context URI' do
          expect(resource.relation(:items).expand({}).to_s).to eq 'http://test.host/users/items'
        end

        it { is_expected.to have_relation :status }
      end

      context 'object with implicit self relation' do
        let(:body) do
          <<-JSON
            {"json": "value", "url": "/self"}
          JSON
        end

        it { expect(resource.relation(:self)).to eq '/self' }
      end

      context 'relation fields in any case' do
        let(:body) do
          <<-JSON
            {"Search_URL": "/search", "URL": "/self"}
          JSON
        end

        it { expect(resource.relation(:search)).to eq '/search' }
        it { expect(resource.relation(:self)).to eq '/self' }
      end

      context 'several fields for the same relation' do
        let(:body) do
          <<-JSON
            {"url": "/first", "self_url": "/second"}
          JSON
        end

        it { expect(resource.relation(:self)).to eq '/first' }
      end

      context 'relation fields without URLs' do
        let(:body) do
          <<-JSON
            {"a_url": null, "c_url": "", "d_url": 42, "e_url": 1.5,
             "f_url": true, "g_url": {"href": "/g"}, "h_url": ["/h"]}
          JSON
        end

        it { expect(resource._restify_relations).to be_empty }
      end

      context 'fields similar to relations' do
        let(:body) do
          <<-JSON
            {"_url": "/a", "url_b": "/b"}
          JSON
        end

        it { expect(resource._restify_relations).to be_empty }
      end

      context 'relation fields with non-ASCII characters' do
        let(:body) do
          <<-JSON
            {"\u00FCber_url": "/a", "\u212A_url": "/kelvin", "\u212Aurl": "/b"}
          JSON
        end

        it { expect(resource._restify_relations).to be_empty }
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
