# frozen_string_literal: true

require 'spec_helper'
require 'active_support'
require 'active_support/cache'

describe Restify::Cache do
  subject(:cache) { described_class.new(store) }

  let(:store) { instance_double(ActiveSupport::Cache::Store) }

  describe '#call' do
    let(:request) { instance_double(Restify::Request) }
    let(:promise0) { instance_double(Restify::Promise, 'promise0') } # rubocop:disable RSpec/IndexedLet
    let(:promise1) { instance_double(Restify::Promise, 'promise1') } # rubocop:disable RSpec/IndexedLet
    let(:response) { instance_double(Restify::Response) }

    it 'yields with promises' do
      allow(promise0).to receive(:then).and_yield(response).and_return(promise1)

      expect(cache.call(request) { promise0 }).to eq promise1
    end

    it 'caches new responses' do
      allow(promise0).to receive(:then).and_yield(response)

      # TODO: Do not stub inside tested object
      expect(cache).to receive(:cache).with(response)

      cache.call(request) { promise0 }
    end

    it 'returns with match' do
      # TODO: Do not stub inside tested object
      expect(cache).to receive(:match).with(request).and_return(response)

      expect(cache.call(request)).to eq response
    end
  end
end
