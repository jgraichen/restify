require 'spec_helper'

describe Restify::Relation do
  let(:client) { double 'client' }
  let(:pattern) { 'http://test.host/resource/{id}' }
  let(:relation) { described_class.new client, pattern }
  subject { relation }

  describe '#==' do
    it 'should equal pattern' do
      expect(subject).to eq pattern
    end
  end
end
