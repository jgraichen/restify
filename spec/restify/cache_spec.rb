require 'spec_helper'

describe Restify::Cache do
  let(:store) { double 'store' }
  let(:cache) { described_class.new store }

  subject { cache }

  describe '#call' do
    let(:request) { double 'request' }
    let(:promise0) { double 'promise0' }
    let(:promise1) { double 'promise1' }
    let(:response) { double 'response' }

    it 'yields with promises' do
      expect(promise0).to receive(:then).and_yield(response).and_return(promise1)

      expect(subject.call(request) { promise0 }).to eq promise1
    end

    it 'caches new responses' do
      expect(promise0).to receive(:then).and_yield(response)
      expect(cache).to receive(:cache).with(response)

      subject.call(request) { promise0 }
    end

    it 'returns with match' do
      expect(cache).to receive(:match).with(request).and_return(response)

      expect(subject.call(request)).to eq response
    end
  end
end
