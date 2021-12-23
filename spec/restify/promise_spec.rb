# frozen_string_literal: true

require 'spec_helper'

describe Restify::Promise do
  let(:promise) { described_class.new }

  describe 'factory methods' do
    describe '#fulfilled' do
      subject { described_class.fulfilled(fulfill_value) }

      let(:fulfill_value) { 42 }

      it 'returns a fulfilled promise' do
        expect(subject.fulfilled?).to be true
        expect(subject.rejected?).to be false
      end

      it 'wraps the given value' do
        expect(subject.value!).to eq 42
      end
    end

    describe '#rejected' do
      subject { described_class.rejected(rejection_reason) }

      let(:rejection_reason) { ArgumentError }

      it 'returns a rejected promise' do
        expect(subject.fulfilled?).to be false
        expect(subject.rejected?).to be true
      end

      it 'bubbles up the caught exception on #value!' do
        expect { subject.value! }.to raise_error(ArgumentError)
      end

      it 'swallows the exception on #value' do
        expect(subject.value).to be nil
      end
    end

    describe '#create' do
      context 'when fulfilling the promise in the writer block' do
        subject do
          described_class.create do |writer|
            # Calculate a value and fulfill the promise with it
            writer.fulfill 42
          end
        end

        it 'returns a fulfilled promise' do
          expect(subject.fulfilled?).to be true
          expect(subject.rejected?).to be false
        end

        it 'wraps the given value' do
          expect(subject.value!).to eq 42
        end
      end

      context 'when rejecting the promise in the writer block' do
        subject do
          described_class.create do |writer|
            # Calculate a value and fulfill the promise with it
            writer.reject ArgumentError
          end
        end

        it 'returns a rejected promise' do
          expect(subject.fulfilled?).to be false
          expect(subject.rejected?).to be true
        end

        it 'bubbles up the caught exception on #value!' do
          expect { subject.value! }.to raise_error(ArgumentError)
        end

        it 'swallows the exception on #value' do
          expect(subject.value).to be nil
        end
      end

      context 'when fulfilling the promise asynchronously' do
        subject do
          described_class.create do |writer|
            Thread.new do
              sleep 0.1
              writer.fulfill 42
            end
          end
        end

        it 'returns a pending promise' do
          expect(subject.fulfilled?).to be false
          expect(subject.rejected?).to be false
          expect(subject.pending?).to be true
        end

        it 'waits for the fulfillment value' do
          expect(subject.value!).to eq 42
        end
      end
    end
  end

  describe 'result' do
    subject { described_class.new(*dependencies, &task).value! }

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
        expect(subject).to eq 42
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
        expect(subject).to eq [1, 2, 3]
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
        expect(subject).to eq [1, 2, 3]
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
        expect(subject).to eq 17
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
      expect { promise.wait(0.1) }.to raise_error ::Timeout::Error
    end
  end

  describe '#value' do
    it 'can time out' do
      expect { promise.value(0.1) }.to raise_error ::Timeout::Error
    end
  end

  describe '#value!' do
    it 'can time out' do
      expect { promise.value!(0.1) }.to raise_error ::Timeout::Error
    end
  end
end
