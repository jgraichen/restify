# frozen_string_literal: true

require 'spec_helper'

describe Restify::Timeout do
  let(:timer) { described_class.new(0.2) }

  describe '#remaining' do
    it 'returns the seconds left' do
      expect(timer.remaining).to be_within(0.05).of(0.2)
    end

    it 'is not positive after having timed out' do
      expired = described_class.new(0.01)
      sleep expired.remaining

      expect(expired.remaining).not_to be_positive
    end
  end

  describe '#exception' do
    it 'names the target and duration' do
      error = described_class.new(0.2, :target).exception

      expect(error).to be_a Restify::Timeout::Error
      expect(error.target).to eq :target
      expect(error.duration).to eq 0.2
      expect(error.message).to eq 'Operation on target timed out after 0.2s'
    end

    it 'names the duration without a target' do
      expect(timer.exception.message).to eq 'Operation timed out after 0.2s'
    end
  end

  describe '.new' do
    it 'returns a given timeout' do
      expect(described_class.new(timer)).to be timer
    end

    it 'uses the default timeout for nil' do
      expect(described_class.new(nil).duration).to eq described_class.default_timeout
    end

    it 'accepts numeric strings' do
      expect(described_class.new('0.2').duration).to eq 0.2
    end

    it 'rejects infinite values' do
      expect { described_class.new(Float::INFINITY) }.to raise_error ArgumentError, /must be finite/
    end

    it 'rejects non-numeric values' do
      expect { described_class.new('soon') }.to raise_error ArgumentError, /must be a number/
      expect { described_class.new(Object.new) }.to raise_error ArgumentError, /must be a number/
    end

    it 'rejects non-positive values' do
      expect { described_class.new(0) }.to raise_error ArgumentError, /must be > 0/
      expect { described_class.new(-1) }.to raise_error ArgumentError, /must be > 0/
      expect { described_class.new(Float::NAN) }.to raise_error ArgumentError, /must be > 0/
    end
  end
end
