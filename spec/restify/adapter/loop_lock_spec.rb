# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::LoopLock do
  subject(:lock) { described_class.new { interrupts << Thread.current } }

  let(:interrupts) { Queue.new }
  let(:threads) { [] }

  after { threads.each(&:kill).each(&:join) }

  # Run the block in another thread, and wait until it has returned.
  # The thread is kept alive until the example finished.
  def other(&)
    done = Concurrent::Event.new
    threads << Thread.new do
      yield
      done.set
      sleep
    end
    expect(done.wait(1)).to be true
  end

  def elapsed
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  end

  describe '#acquire' do
    it 'acquires a free loop' do
      expect(lock.acquire(1)).to be true
      expect(lock).to be_owned
    end

    it 'does not acquire the loop when done' do
      expect(lock.acquire(1) { true }).to be false
      expect(lock).not_to be_owned
    end

    it 'times out while another thread holds the loop' do
      other { lock.acquire(1) }

      expect(elapsed { expect(lock.acquire(0.1)).to be false }).to be >= 0.1
      expect(lock).not_to be_owned
    end

    it 'waits for another thread to release the loop' do
      acquired = Concurrent::Event.new
      released = false
      threads << Thread.new do
        lock.acquire(1)
        acquired.set
        sleep 0.1
        released = true
        lock.release
      end
      expect(acquired.wait(1)).to be true

      expect(lock.acquire(1)).to be true
      expect(released).to be true
    end

    it 'stops waiting when done after being notified' do
      done = false
      other { lock.acquire(1) }
      threads << Thread.new do
        sleep 0.1
        done = true
        lock.notify
      end

      expect(elapsed { expect(lock.acquire(1) { done }).to be false }).to be < 0.5
    end

    it 'treats a dead thread as not holding the loop' do
      Thread.new { lock.acquire(1) }.join

      expect(lock.acquire(0.1)).to be true
    end
  end

  describe '#release' do
    it 'lets a waiting thread acquire the loop' do
      lock.acquire(1)
      waiter = Thread.new { lock.acquire(1) }
      sleep 0.05

      lock.release

      expect(waiter.join(1)&.value).to be true
      expect(lock).not_to be_owned
    end
  end

  describe 'with a background thread' do
    let(:background) { Queue.new }

    # A background thread running the loop until interrupted, like an
    # event loop waiting for sockets. Blocks on `interrupts` on purpose,
    # and is killed after each example.
    def start_background
      threads << Thread.new do
        loop do
          lock.acquire_background
          background << :acquired
          interrupts.pop
          lock.release
        end
      end

      expect(background.pop(timeout: 1)).to eq :acquired
    end

    it 'interrupts the background thread to release the loop' do
      start_background

      expect(lock.acquire(1)).to be true
      expect(background).to be_empty
    end

    it 'blocks the background thread while a thread holds the loop' do
      start_background
      lock.acquire(1)

      sleep 0.1
      expect(background).to be_empty

      lock.release
      expect(background.pop(timeout: 1)).to eq :acquired
    end
  end

  describe '#reset!' do
    it 'forgets threads holding the loop' do
      other { lock.acquire(1) }

      lock.reset!

      expect(lock.acquire(0.1)).to be true
    end
  end
end
