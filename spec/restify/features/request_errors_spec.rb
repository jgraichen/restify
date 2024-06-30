# frozen_string_literal: true

require 'spec_helper'

describe Restify, adapter: 'Restify::Adapter::Typhoeus' do
  before do
    stub_request(:get, 'http://stubserver/base').to_timeout
  end

  describe 'Timeout' do
    subject(:request) { Restify.new('http://localhost:9292/base').get({}, timeout: 0.1).value! }

    it 'throws a network error' do
      expect { request }.to raise_error Restify::NetworkError do |error|
        expect(error.message).to match(/timeout/i)
      end
    end
  end
end
