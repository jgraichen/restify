# frozen_string_literal: true

require 'spec_helper'

describe Restify::Resource do
  subject { resource }

  let(:data)      { {} }
  let(:relations) { {} }
  let(:context)   { double 'context' }
  let(:response)  { double 'response' }
  let(:resource)  { described_class.new(context, response:, data:, relations:) }

  before do
    allow(context).to receive(:relation?).and_return(false)
    allow(context).to receive(:relation).and_raise(KeyError)
  end

  context 'relations' do
    let(:relations) do
      {
        'users' => 'http://example.org/users',
        'projects' => 'http://example.org/projects',
      }
    end

    describe '#relation?' do
      it 'matches relations' do
        expect(subject.relation?(:users)).to be true
        expect(subject.relation?('users')).to be true
        expect(subject.relation?(:projects)).to be true
        expect(subject.relation?('projects')).to be true
        expect(subject.relation?('fuu')).to be false

        expect(subject).to have_relation :users
        expect(subject).to have_relation :projects

        expect(subject.rel?(:users)).to be true
        expect(subject.rel?('users')).to be true
        expect(subject.rel?(:projects)).to be true
        expect(subject.rel?('projects')).to be true
        expect(subject.rel?('fuu')).to be false

        expect(subject).to have_rel :users
        expect(subject).to have_rel :projects
      end
    end

    describe '#relation' do
      it 'returns relation' do
        expect(subject.rel(:users)).to be_a Restify::Relation

        expect(subject.rel(:users)).to eq 'http://example.org/users'
        expect(subject.rel('users')).to eq 'http://example.org/users'
        expect(subject.rel(:projects)).to eq 'http://example.org/projects'
        expect(subject.rel('projects')).to eq 'http://example.org/projects'
        expect { subject.rel(:fuu) }.to raise_error KeyError

        expect(subject.relation(:users)).to eq 'http://example.org/users'
        expect(subject.relation('users')).to eq 'http://example.org/users'
        expect(subject.relation(:projects)).to eq 'http://example.org/projects'
        expect(subject.relation('projects')).to eq 'http://example.org/projects'
        expect { subject.relation(:fuu) }.to raise_error KeyError
      end
    end

    describe '#follow' do
      let(:relations) { {_restify_follow: 'http://localhost/10'} }

      it 'returns follow relation' do
        expect(subject.follow).to be_a Restify::Relation
        expect(subject.follow).to eq 'http://localhost/10'
      end

      context 'when nil' do
        let(:relations) { {} }

        it 'returns nil' do
          expect(subject.follow).to be_nil
        end
      end
    end

    describe '#follow!' do
      let(:relations) { {_restify_follow: 'http://localhost/10'} }

      it 'returns follow relation' do
        expect(subject.follow!).to be_a Restify::Relation
        expect(subject.follow!).to eq 'http://localhost/10'
      end

      context 'when nil' do
        let(:relations) { {} }

        it 'raise runtime error' do
          expect { subject.follow! }.to raise_error RuntimeError do |err|
            expect(err.message).to eq 'Nothing to follow'
          end
        end
      end
    end
  end

  context 'data' do
    let(:data) { double 'data' }

    it 'delegates methods (I)' do
      expect(data).to receive(:some_method).and_return(42)

      expect(subject).to respond_to :some_method
      expect(subject.some_method).to eq 42
    end

    it 'delegates methods (II)' do
      expect(data).to receive(:[]).with(1).and_return(2)

      expect(subject).to respond_to :[]
      expect(subject[1]).to eq 2
    end

    describe '#data' do
      it 'returns data' do
        expect(subject.data).to equal data
      end
    end
  end
end
