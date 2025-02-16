# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  before do
    WebMock.enable!
  end

  after do
    WebMock.disable!(except: %i[net_http])
  end

  describe 'WebMock' do
    subject(:resource) { Restify.new('http://www.example.com/base').get.value! }

    it 'can stub requests' do
      stub_request(:any, 'http://www.example.com/base')

      expect(resource.response.status).to eq(:ok)
    end

    it 'raises error for not stubbed requests' do
      expect { resource }.to raise_error WebMock::NetConnectNotAllowedError
    end
  end
end
