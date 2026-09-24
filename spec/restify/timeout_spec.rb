# frozen_string_literal: true

require 'spec_helper'

describe Restify::Timeout do
  let(:timer) { described_class.new(0.2) }

  describe '#timeout!' do
    context 'before having timed out' do
      it 'do nothing' do
        expect { timer.timeout! }.not_to raise_error
      end
    end

    context 'after having timed out' do
      it 'calls given block' do
        expect { timer.timeout! }.not_to raise_error
        sleep timer.send(:wait_interval)
        expect { timer.timeout! }.to raise_error Restify::Timeout::Error
      end
    end
  end

  describe '#remaining' do
    it 'returns the seconds left' do
      expect(timer.remaining).to be_within(0.05).of(0.2)
    end

    it 'is not positive after having timed out' do
      sleep timer.remaining
      expect(timer.remaining).not_to be_positive
    end
  end

  describe '#wait_on!' do
    it 'calls block on IVar timeout' do
      expect do
        timer.wait_on!(Concurrent::IVar.new)
      end.to raise_error Restify::Timeout::Error
    end

    it 'calls block on Promise timeout' do
      expect do
        timer.wait_on!(Restify::Promise.new)
      end.to raise_error Restify::Timeout::Error
    end

    it 'does nothing on successful IVar' do
      expect do
        Concurrent::IVar.new.tap do |ivar|
          Thread.new { ivar.set :success }
          expect(timer.wait_on!(ivar)).to eq :success
        end
      end.not_to raise_error
    end

    it 'does nothing on successful Promise' do
      expect do
        Restify::Promise.fulfilled(:success).tap do |p|
          expect(timer.wait_on!(p)).to eq :success
        end
      end.not_to raise_error
    end
  end
end
