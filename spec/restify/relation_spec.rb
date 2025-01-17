# frozen_string_literal: true

require 'spec_helper'
require 'active_support'

describe Restify::Relation do
  subject(:relation) { described_class.new context, pattern }

  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:pattern)  { '/resource/{id}' }

  describe '#==' do
    it 'equals pattern' do
      expect(relation).to eq pattern
    end
  end

  describe '#expand' do
    subject(:expanded) { relation.expand params }

    let(:params) { {id: 1337} }
    let(:cls_to_param) do
      Class.new do
        def to_param
          42
        end
      end
    end

    it { is_expected.to be_a Addressable::URI }

    context 'with nil' do
      let(:params) { {id: nil} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/' }
    end

    context 'with false' do
      let(:params) { {id: false} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/' }
    end

    context 'with true' do
      let(:params) { {id: true} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/true' }
    end

    context 'with #to_param object' do
      let(:params) { {id: cls_to_param.new} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/42' }
    end

    context 'with array parameter' do
      let(:params) { {id: [1, 2]} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/1,2' }
    end

    context 'with unknown additional query parameter' do
      let(:pattern) { '/resource{?a,b}' }
      let(:params) { {a: 1, b: 2, c: 3} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource?a=1&b=2&c=3' }
    end

    context 'with additional parameters' do
      let(:params) { {id: '5', abc: 'cde'} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=cde' }
    end

    context 'with additional nil parameters' do
      let(:params) { {id: '5', abc: nil} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc' }
    end

    context 'with additional false parameters' do
      let(:params) { {id: '5', abc: false} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=false' }
    end

    context 'with additional true parameters' do
      let(:params) { {id: '5', abc: true} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=true' }
    end

    context 'with additional #to_param parameter' do
      let(:params) { {id: '5', abc: cls_to_param.new} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=42' }
    end

    context 'with additional array parameter' do
      let(:params) { {id: 5, abc: [1, 2]} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=1&abc=2' }
    end

    context 'with additional array parameter with objects' do
      let(:params) { {id: 5, abc: [1, 2, cls_to_param.new]} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/5?abc=1&abc=2&abc=42' }
    end

    context 'with additional nested array parameter' do
      let(:params) { {id: 5, abc: [1, 2, [1]]} }

      it { expect { expanded }.to raise_exception TypeError, /Can't convert Array into String./ }
    end

    context 'with additional hash parameter' do
      let(:params) { {id: 5, abc: {a: 1, b: 2}} }

      it { expect { expanded }.to raise_exception TypeError, /Can't convert Hash into String./ }
    end
  end
end
