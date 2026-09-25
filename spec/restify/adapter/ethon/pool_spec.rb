# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon::Pool do
  subject(:pool) do
    described_class.new(size: 2) do
      created << Handle.new(0, Pointer.new(true))
      created.last
    end
  end

  let(:created) { [] }

  before do
    stub_const('Pointer', Struct.new(:autorelease))
    stub_const('Handle', Struct.new(:resets, :handle) do
      def reset
        self.resets += 1
      end
    end,)
  end

  def release(*handles)
    handles.each {|handle| pool.complete(handle) }
    pool.release_completed
  end

  describe '#checkout' do
    it 'creates a handle when none is idle' do
      expect(pool.checkout).to be created.first
    end

    it 'reuses released handles' do
      handle = pool.checkout
      release(handle)

      expect(pool.checkout).to be handle
      expect(created.size).to eq 1
    end

    it 'returns distinct handles to concurrent threads' do
      release(*Array.new(2) { pool.checkout })

      handles = Array.new(4) { Thread.new { pool.checkout } }.map(&:value)

      expect(handles.map(&:object_id).uniq.size).to eq 4
    end
  end

  describe '#complete' do
    it 'does not make the handle available before its release' do
      handle = pool.checkout
      pool.complete(handle)

      expect(pool.checkout).not_to be handle
    end
  end

  describe '#release_completed' do
    it 'resets handles' do
      handle = pool.checkout
      release(handle)

      expect(handle.resets).to eq 1
    end

    it 'keeps a limited number of idle handles' do
      released = Array.new(3) { pool.checkout }
      release(*released)

      # Two of them are reused, the third one is created anew.
      reused = Array.new(3) { pool.checkout }

      expect(reused.count {|handle| released.any? {|r| r.equal?(handle) } }).to eq 2
      expect(created.size).to eq 4
    end
  end

  describe '#forked!' do
    it 'does not release idle or completed handles' do
      idle = pool.checkout
      completed = pool.checkout
      release(idle)
      pool.complete(completed)

      pool.forked!

      expect([idle, completed].map {|handle| handle.handle.autorelease }).to eq [false, false]
      expect(pool.checkout).not_to be idle
    end
  end
end
