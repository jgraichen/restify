# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Typhoeus do
  let(:request) { Restify::Request.new(uri: 'http://localhost:9292/base') }

  before do
    stub_request(:get, 'http://stubserver/base').to_return(status: 200, body: '{}')
  end

  describe 'sync' do
    let(:adapter) { described_class.new(sync: true) }

    it 'runs requests from many threads' do
      threads = Array.new(4) do
        Thread.new { Array.new(10) { adapter.call(request).value!.code } }
      end

      # Do not hang the suite on a deadlock.
      expect(threads.map {|thread| thread.join(5)&.value }).to all eq Array.new(10, 200)
    ensure
      threads&.each(&:kill)
    end
  end
end
