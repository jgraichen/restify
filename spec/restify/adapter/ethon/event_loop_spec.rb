# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon::EventLoop do
  subject(:events) { described_class.new { steps << Thread.current } }

  # Threads that completed an iteration of the loop.
  let(:steps) { Queue.new }
  let(:threads) { [] }

  let(:options) do
    Restify::Adapter::Ethon::Options.new(Restify::Adapter::Ethon::ENFORCED_OPTIONS)
  end

  before do
    stub_request(:get, 'http://stubserver/base').to_return(status: 200, body: '{}')
  end

  after { threads.each(&:kill).each(&:join) }

  # A prepared easy handle with its promise, and a queue recording the
  # thread completing it.
  def transfer
    request = Restify::Request.new(uri: 'http://localhost:9292/base')
    writer = nil
    promise = Restify::Promise.create {|w| writer = w }
    completed_by = Queue.new

    easy = Restify::Adapter::Ethon::Easy.new
    easy._restify_request = request
    easy._restify_writer = writer
    easy.prepare(request, options)
    easy.on_complete do |completed|
      completed_by << Thread.current
      writer.set { completed.response(request) }
      events.notify
    end

    [easy, promise, completed_by]
  end

  describe '#drive' do
    it 'runs transfers in the calling thread' do
      easy, promise, completed_by = transfer
      events.enqueue(easy)

      expect(events.drive(promise, Restify::Timeout.new(1))).to be true
      expect(promise.value.code).to eq 200
      expect(completed_by.pop(timeout: 1)).to eq Thread.current
    end

    it 'calls the block after iterations' do
      easy, promise, = transfer
      events.enqueue(easy)
      events.drive(promise, Restify::Timeout.new(1))

      expect(steps.pop(timeout: 1)).to eq Thread.current
    end

    it 'gives up when the timeout expires' do
      expect(events.drive(Restify::Promise.new, Restify::Timeout.new(0.1))).to be true
    end

    it 'does not run the loop again from within the loop' do
      events.instance_variable_get(:@lock).acquire(0.1)

      expect(events.drive(Restify::Promise.new, Restify::Timeout.new(0.1))).to be false
    end
  end

  describe '#run' do
    it 'completes transfers enqueued from other threads' do
      background = Thread.new { events.run }
      threads << background

      easy, promise, completed_by = transfer
      events.enqueue(easy)

      expect(completed_by.pop(timeout: 1)).to eq background
      expect(promise).to be_fulfilled
    end
  end

  describe '#forked!' do
    it 'rejects pending transfers' do
      easy, promise, = transfer
      events.enqueue(easy)

      events.forked!

      expect(promise).to be_rejected
      expect(promise.reason).to be_a Restify::NetworkError
      expect(promise.reason.message).to include 'Request started before fork'
    end

    it 'does not release pending handles' do
      easy, = transfer
      events.enqueue(easy)

      events.forked!

      expect(easy.handle.autorelease?).to be false
    end
  end
end
