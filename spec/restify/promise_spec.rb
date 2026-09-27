# frozen_string_literal: true

require 'spec_helper'

describe Restify::Promise do
  let(:promise) { described_class.new }
  let(:threads) { [] }

  after do
    threads.each(&:kill).each(&:join)
  end

  def pending_promise
    writer = nil
    promise = described_class.create {|w| writer = w }
    [promise, writer]
  end

  # Run the block in another thread, and return once the thread blocks,
  # e.g. waiting on a promise.
  def blocking(&)
    thread = Thread.new(&)
    threads << thread
    Thread.pass until thread.stop?
    thread
  end

  describe 'factory methods' do
    describe '#fulfilled' do
      subject(:promise) { described_class.fulfilled(fulfill_value) }

      let(:fulfill_value) { 42 }

      it 'returns a fulfilled promise' do
        expect(promise.fulfilled?).to be true
        expect(promise.rejected?).to be false
      end

      it 'wraps the given value' do
        expect(promise.value!).to eq 42
      end
    end

    describe '#rejected' do
      subject(:promise) { described_class.rejected(rejection_reason) }

      let(:rejection_reason) { ArgumentError }

      it 'returns a rejected promise' do
        expect(promise.fulfilled?).to be false
        expect(promise.rejected?).to be true
      end

      it 'bubbles up the caught exception on #value!' do
        expect { promise.value! }.to raise_error(ArgumentError)
      end

      it 'swallows the exception on #value' do
        expect(promise.value).to be_nil
      end
    end

    describe '#create' do
      context 'when fulfilling the promise in the writer block' do
        subject(:promise) do
          described_class.create do |writer|
            # Calculate a value and fulfill the promise with it
            writer.fulfill 42
          end
        end

        it 'returns a fulfilled promise' do
          expect(promise.fulfilled?).to be true
          expect(promise.rejected?).to be false
        end

        it 'wraps the given value' do
          expect(promise.value!).to eq 42
        end
      end

      context 'when rejecting the promise in the writer block' do
        subject(:promise) do
          described_class.create do |writer|
            # Calculate a value and fulfill the promise with it
            writer.reject ArgumentError
          end
        end

        it 'returns a rejected promise' do
          expect(promise.fulfilled?).to be false
          expect(promise.rejected?).to be true
        end

        it 'bubbles up the caught exception on #value!' do
          expect { promise.value! }.to raise_error(ArgumentError)
        end

        it 'swallows the exception on #value' do
          expect(promise.value).to be_nil
        end
      end

      context 'when resolving the promise from a block' do
        subject(:promise) do
          described_class.create do |writer|
            writer.set { block.call }
          end
        end

        context 'with a returned value' do
          let(:block) { -> { 42 } }

          it 'fulfills the promise with it' do
            expect(promise.fulfilled?).to be true
            expect(promise.value!).to eq 42
          end
        end

        context 'with a raised exception' do
          let(:block) { -> { raise ArgumentError.new('nope') } }

          it 'rejects the promise with it' do
            expect(promise.rejected?).to be true
            expect { promise.value! }.to raise_error ArgumentError, 'nope'
          end
        end

        # Handlers can run from e.g. a libcurl callback, from where no
        # exception must ever escape, not even a non-StandardError.
        context 'with a raised non-StandardError' do
          let(:block) { -> { raise NotImplementedError.new('nope') } }

          it 'rejects the promise with it' do
            expect(promise.rejected?).to be true
            expect { promise.value! }.to raise_error NotImplementedError, 'nope'
          end
        end
      end

      context 'when fulfilling the promise later' do
        it 'returns a pending promise' do
          promise, = pending_promise

          expect(promise.fulfilled?).to be false
          expect(promise.rejected?).to be false
          expect(promise.pending?).to be true
        end

        it 'waits for the fulfillment value' do
          promise, writer = pending_promise
          waiter = blocking { promise.value! }

          writer.fulfill 42
          expect(waiter.value).to eq 42
        end
      end
    end
  end

  describe 'result' do
    subject(:result) { described_class.new(*dependencies, &task).value! }

    let(:dependencies) { [] }
    let(:task) { nil }

    context 'with a task' do
      let(:task) do
        proc {
          # Calculate the resulting value
          38 + 4
        }
      end

      it 'is calculated using the task block' do
        expect(result).to eq 42
      end
    end

    context 'with a task raising an exception' do
      let(:task) { proc { raise ArgumentError.new('kaboom') } }

      it 'rejects the promise with it' do
        expect { result }.to raise_error ArgumentError, 'kaboom'
      end
    end

    # No exception must escape from a task, not even a non-StandardError.
    context 'with a task raising a non-StandardError' do
      let(:task) { proc { raise NotImplementedError.new('kaboom') } }

      it 'rejects the promise with it' do
        expect { result }.to raise_error NotImplementedError, 'kaboom'
      end
    end

    context 'with dependencies, but no task' do
      let(:dependencies) do
        [
          Restify::Promise.fulfilled(1),
          Restify::Promise.fulfilled(2),
          Restify::Promise.fulfilled(3),
        ]
      end

      it 'is an array of the dependencies\' results' do
        expect(result).to eq [1, 2, 3]
      end
    end

    context 'with dependencies passed as an array, but no task' do
      let(:dependencies) do
        [[
          Restify::Promise.fulfilled(1),
          Restify::Promise.fulfilled(2),
          Restify::Promise.fulfilled(3),
        ]]
      end

      it 'is an array of the dependencies\' results' do
        expect(result).to eq [1, 2, 3]
      end
    end

    context 'with dependencies and a task' do
      let(:dependencies) do
        [
          Restify::Promise.fulfilled(5),
          Restify::Promise.fulfilled(12),
        ]
      end
      let(:task) do
        proc {|dep1, dep2| dep1 + dep2 }
      end

      it 'can use the dependencies to calculate the value' do
        expect(result).to eq 17
      end
    end

    # Nobody does this explicitly, but it can happen when the array of
    # dependencies is built dynamically.
    context 'with an empty array of dependencies and without task' do
      subject { described_class.new([]).value! }

      it { is_expected.to eq [] }
    end
  end

  describe '#wait' do
    it 'can time out' do
      expect { promise.wait(0.01) }.to raise_error Timeout::Error
    end

    context 'with a driver' do
      subject(:promise) { described_class.create(driver:) {|w| writers << w } }

      let(:driver) { instance_double(Restify::Adapter::Ethon) }
      let(:writers) { [] }
      let(:writer) { writers.first }

      before { promise }

      it 'lets the driver complete the promise in the waiting thread' do
        expect(driver).to receive(:drive).once do |p, timeout|
          expect(p).to be promise
          expect(timeout).to be_a Restify::Timeout
          writer.fulfill 42
          true
        end

        expect(promise.value!).to eq 42
      end

      it 'waits as usual when the driver declines' do
        allow(driver).to receive(:drive).and_return(false)
        waiter = blocking { promise.value! }

        writer.fulfill 42
        expect(waiter.value).to eq 42
      end

      it 'times out when the driver returns without completing it' do
        allow(driver).to receive(:drive).and_return(true)

        expect { promise.wait(0.01) }.to raise_error Timeout::Error
      end

      it 'does not call the driver for a complete promise' do
        expect(driver).not_to receive(:drive)
        writer.fulfill 42

        expect(promise.value!).to eq 42
      end
    end
  end

  describe 'timeouts' do
    it 'uses the default timeout' do
      previous = Restify::Timeout.default_timeout
      Restify::Timeout.default_timeout = 0.01

      expect { promise.wait }.to raise_error Restify::Timeout::Error
    ensure
      Restify::Timeout.default_timeout = previous
    end

    it 'does not reject the promise' do
      dependency, writer = pending_promise
      chained = dependency.then {|v| v + 1 }

      expect { chained.value!(0.01) }.to raise_error Restify::Timeout::Error
      expect(chained).to be_pending

      writer.fulfill 1
      expect(chained.value!).to eq 2
    end

    it 'does not run the task again after a timeout' do
      calls = 0
      inner, writer = pending_promise
      chained = described_class.fulfilled(1).then do
        calls += 1
        inner
      end

      expect { chained.value!(0.01) }.to raise_error Restify::Timeout::Error

      writer.fulfill 2
      expect(chained.value!).to eq 2
      expect(calls).to eq 1
    end

    it 'times out while another thread runs the task' do
      dependency, writer = pending_promise
      chained = dependency.then {|v| v + 1 }
      running = blocking { chained.value! }

      expect { chained.value!(0.01) }.to raise_error Restify::Timeout::Error
      expect(running).to be_alive

      writer.fulfill 1
      expect(running.value).to eq 2
    end

    # Giving up after a timeout releases the claim the same way.
    it 'lets a waiting thread take over when the running thread is killed' do
      dependency, writer = pending_promise
      chained = dependency.then {|v| v + 1 }
      running = blocking { chained.value! }
      waiting = blocking { chained.value! }

      running.kill.join

      writer.fulfill 1
      expect(waiting.value).to eq 2
    end

    it 'runs the task once for concurrent waiters' do
      dependency, writer = pending_promise
      calls = Queue.new
      chained = dependency.then {|v| calls << v }
      waiters = Array.new(5) { blocking { chained.value! } }

      writer.fulfill 1
      waiters.each(&:join)
      expect(calls.size).to eq 1
    end
  end

  describe '#then' do
    it 'waits on a promise returned from the task' do
      chained = described_class.fulfilled(1).then do |v|
        described_class.fulfilled(v + 1)
      end

      expect(chained.value!).to eq 2
    end

    it 'rejects with the reason of a rejected dependency' do
      chained = described_class.rejected(ArgumentError.new('nope')).then { 42 }

      expect { chained.value! }.to raise_error ArgumentError, 'nope'
    end

    it 'rejects with the reason of a promise returned from the task' do
      chained = described_class.fulfilled(1).then do
        described_class.rejected(ArgumentError.new('nope'))
      end

      expect { chained.value! }.to raise_error ArgumentError, 'nope'
    end

    it 'runs lazily' do
      calls = 0
      chained = described_class.fulfilled(1).then { calls += 1 }

      expect(calls).to eq 0
      chained.value!
      expect(calls).to eq 1
    end
  end

  describe '#add_observer' do
    let(:writers) { [] }
    let(:promise) { described_class.create {|w| writers << w } }
    let(:writer) { writers.first }

    before { promise }

    it 'is called when fulfilled' do
      calls = []
      promise.add_observer {|value, reason| calls << [value, reason] }

      expect(calls).to eq []
      writer.fulfill 42
      expect(calls).to eq [[42, nil]]
    end

    it 'is called when rejected' do
      error = ArgumentError.new
      calls = []
      promise.add_observer {|value, reason| calls << [value, reason] }

      writer.reject error
      expect(calls).to eq [[nil, error]]
    end

    it 'is called right away when already complete' do
      calls = []
      writer.fulfill 42

      promise.add_observer {|value, _| calls << value }
      expect(calls).to eq [42]
    end

    it 'calls later observers when one raises' do
      calls = []
      promise.add_observer { raise 'kaboom' }
      promise.add_observer {|value, _| calls << value }

      expect { writer.fulfill 42 }.not_to raise_error
      expect(calls).to eq [42]
    end
  end

  describe 'Writer' do
    let(:writers) { [] }
    let(:promise) { described_class.create {|w| writers << w } }
    let(:writer) { writers.first }

    before { promise }

    it 'cannot complete a promise twice' do
      writer.fulfill 1

      expect { writer.fulfill 2 }.to raise_error Restify::Promise::AlreadyCompleteError
      expect { writer.reject ArgumentError }.to raise_error Restify::Promise::AlreadyCompleteError
      expect { writer.set { 2 } }.to raise_error Restify::Promise::AlreadyCompleteError
      expect(promise.value!).to eq 1
    end
  end

  describe '#value' do
    it 'can time out' do
      expect { promise.value(0.01) }.to raise_error Timeout::Error
    end
  end

  describe '#value!' do
    it 'can time out' do
      expect { promise.value!(0.01) }.to raise_error Timeout::Error
    end
  end
end
