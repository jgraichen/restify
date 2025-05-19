# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Base do
  subject(:adapter) { described_class.new }

  let(:request) { Restify::Request.new(uri: 'https://example.org') }

  describe '#call' do
    subject(:call) { adapter.call(request) }

    it 'delegates to call_native with a promise' do
      expect(adapter).to receive(:call_native) do |req, writer| # rubocop:disable RSpec/SubjectStub
        expect(req).to be request
        expect(writer).to be_a Restify::Promise::Writer
      end

      call.tap do |promise|
        expect(promise).to be_a Restify::Promise
        expect(promise).to be_pending
      end
    end
  end

  describe '#call_native' do
    subject(:call_native) { adapter.call_native(nil, nil) }

    it 'must be implemented in a subclass' do
      expect { call_native }.to raise_error(NotImplementedError)
    end
  end
end
