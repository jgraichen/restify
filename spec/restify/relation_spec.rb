# frozen_string_literal: true

require 'spec_helper'

describe Restify::Relation do
  subject(:relation) { described_class.new context, pattern }

  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:pattern)  { '/resource/{id}' }

  describe '#==' do
    it 'equals pattern' do
      expect(subject).to eq pattern
    end
  end

  describe '#expand' do
    subject(:expaned) { relation.expand params }

    let(:params) { {id: 1337} }
    let(:cls_to_param) do
      Class.new do
        def to_param
          42
        end
      end
    end

    it { is_expected.to be_a Addressable::URI }

    context 'with #to_param object' do
      let(:params) { {id: cls_to_param.new} }

      it { expect(expaned.to_s).to eq 'http://test.host/resource/42' }
    end

    context 'with unknown additional query parameter' do
      let(:pattern) { '/resource{?a,b}' }
      let(:params) { {a: 1, b: 2, c: 3} }

      it { expect(expaned.to_s).to eq 'http://test.host/resource?a=1&b=2&c=3' }
    end

    context 'with additional parameters' do
      let(:params) { {id: '5', abc: 'cde'} }

      it { expect(expaned.to_s).to eq 'http://test.host/resource/5?abc=cde' }
    end

    context 'with additional #to_param parameter' do
      let(:params) { {id: '5', abc: cls_to_param.new} }

      it { expect(expaned.to_s).to eq 'http://test.host/resource/5?abc=42' }
    end
  end
end
