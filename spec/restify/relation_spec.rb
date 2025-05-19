# frozen_string_literal: true

require 'spec_helper'
require 'active_support'

describe Restify::Relation do
  subject(:relation) { described_class.new context, pattern }

  let(:context)  { Restify::Context.new('http://test.host/') }
  let(:pattern)  { '/resource/{id}{?q*}' }

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

      it { expect(expanded.to_s).to eq 'http://test.host/resource/false' }
    end

    context 'with true' do
      let(:params) { {id: true} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/true' }
    end

    context 'with Object' do
      let(:object) do
        Class.new do
          undef to_param
        end.new
      end
      let(:params) { {id: object} }

      it 'raise a TypeError from adressable' do
        expect { expanded }.to raise_error(TypeError, /Can't convert #<Class:0x.*> into String or Array/)
      end
    end

    context 'with #to_param object' do
      let(:params) { {id: cls_to_param.new} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/42' }
    end

    context 'with array parameter' do
      let(:params) { {id: [1, 2]} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource/1,2' }
    end

    context 'with nil query parameter' do
      let(:pattern) { '/resource{?abc}' }
      let(:params) { {abc: nil} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource' }
    end

    context 'with false query parameter' do
      let(:pattern) { '/resource{?abc}' }
      let(:params) { {abc: false} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource?abc=false' }
    end

    context 'with true query parameter' do
      let(:pattern) { '/resource{?abc}' }
      let(:params) { {abc: true} }

      it { expect(expanded.to_s).to eq 'http://test.host/resource?abc=true' }
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

    context 'with string-keyed params' do
      context 'with value' do
        let(:params) { {'id' => 1} }

        it { expect(expanded.to_s).to eq 'http://test.host/resource/1' }
      end
    end

    context 'with mixed-keyed params' do
      context 'non-overlapping' do
        let(:params) { {'id' => 1, q: 2} }

        it { expect(expanded.to_s).to eq 'http://test.host/resource/1?q=2' }
      end

      context 'overlapping (1)' do
        let(:params) { {'id' => 1, id: 2} }

        it 'prefers symbol value' do
          expect(expanded.to_s).to eq 'http://test.host/resource/2'
        end
      end

      context 'overlapping (2)' do
        let(:params) { {id: 2, 'id' => 1} }

        it 'prefers symbol value' do
          expect(expanded.to_s).to eq 'http://test.host/resource/2'
        end
      end
    end
  end

  shared_examples 'non-data-request' do |method|
    it "issues a #{method.upcase} request" do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/'
        expect(opts).to be_nil
      end
      relation.send(method)
    end

    it 'accepts params as keyword argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to be_nil
      end
      relation.send(method, params: {id: 1})
    end

    it 'accepts params as positional argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to be_nil
      end
      relation.send(method, {id: 1})
    end

    it 'merges keyword params into positional params' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1?a=2&b=3'
        expect(opts).to be_nil
      end
      relation.send(method, {id: 1, q: {a: 1, c: 1}}, params: {q: {a: 2, b: 3}})
    end
  end

  describe '#get' do
    include_examples 'non-data-request', :get
  end

  describe '#head' do
    include_examples 'non-data-request', :head
  end

  describe '#delete' do
    include_examples 'non-data-request', :delete
  end

  shared_examples 'data-request' do |method|
    let(:data) { Object.new }

    it "issues a #{method.upcase} request" do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/'
        expect(opts).to eq({data: nil})
      end
      relation.send(method)
    end

    it 'accepts params as keyword argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to eq({data: nil})
      end
      relation.send(method, params: {id: 1})
    end

    it 'accepts data as keyword argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to eq({data:})
      end
      relation.send(method, data:, params: {id: 1})
    end

    it 'accepts data as position argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to eq({data:})
      end
      relation.send(method, data, params: {id: 1})
    end

    it 'prefers data from keyword argument' do
      expect(context).to receive(:request) do |meth, uri, opts|
        expect(meth).to eq method
        expect(uri.to_s).to eq 'http://test.host/resource/1'
        expect(opts).to eq({data:})
      end
      relation.send(method, 'DATA', data:, params: {id: 1})
    end
  end

  describe '#post' do
    include_examples 'data-request', :post
  end

  describe '#put' do
    include_examples 'data-request', :put
  end

  describe '#patch' do
    include_examples 'data-request', :patch
  end

  describe '#to_s' do
    subject(:string) { relation.to_s }

    it { is_expected.to eq '/resource/{id}{?q*}' }
  end
end
