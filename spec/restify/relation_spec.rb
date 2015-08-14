require 'spec_helper'

describe Restify::Relation do
  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:pattern)  { '/resource/{id}' }
  let(:relation) { described_class.new context, pattern }
  subject { relation }

  describe '#==' do
    it 'should equal pattern' do
      expect(subject).to eq pattern
    end
  end

  describe '#expand' do
    let(:params) { {id: 1337} }

    subject { relation.expand params }

    it { is_expected.to be_a Addressable::URI }

    class ParamObject
      def to_param
        42
      end
    end

    context 'with #to_param object' do

      let(:params) { {id: ParamObject.new} }

      it { expect(subject.to_s).to eq 'http://test.host/resource/42' }
    end

    context 'with unknown additional query parameter' do
      let(:pattern) { '/resource{?a,b}' }
      let(:params) { {a: 1, b: 2, c: 3} }

      it { expect(subject.to_s).to eq 'http://test.host/resource?a=1&b=2&c=3' }
    end

    context 'with additional parameters' do
      let(:params) { {id: '5', abc: 'cde'} }

      it { expect(subject.to_s).to eq 'http://test.host/resource/5?abc=cde' }
    end

    context 'with additional #to_param parameter' do
      let(:params) { {id: '5', abc: ParamObject.new} }

      it { expect(subject.to_s).to eq 'http://test.host/resource/5?abc=42' }
    end
  end
end
