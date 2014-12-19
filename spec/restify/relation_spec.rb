require 'spec_helper'

describe Restify::Relation do
  let(:context) { double 'context' }
  let(:source) { '/resource/{id}' }
  let(:pattern) { "http://test.host#{source}" }
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

  describe '#expand' do
    let(:params) { {id: 1337} }

    subject { relation.expand params }

    it { is_expected.to be_a Addressable::URI }

    context 'with #to_param object' do
      class ParamObject
        def to_param
          42
        end
      end

      let(:params) { {id: ParamObject.new} }

      it { expect(subject.to_s).to eq 'http://test.host/resource/42' }
    end

    context 'with additional parameters' do
      let(:params) { {id: '5', abc: 'cde'} }

      it { expect(subject.to_s).to eq 'http://test.host/resource/5?abc=cde' }
    end
  end
end
