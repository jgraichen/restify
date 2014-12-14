require 'spec_helper'

describe Restify::Relation do
  let(:context) { double 'context' }
  let(:source) { '/resource/{id}' }
  let(:pattern) { "http://test.host/#{source}" }
  let(:relation) { described_class.new context, source, pattern }
  subject { relation }

  describe '#==' do
    it 'should equal source' do
      expect(subject).to eq source
    end

    it 'should equal pattern' do
      expect(subject).to eq pattern
    end
  end
end
