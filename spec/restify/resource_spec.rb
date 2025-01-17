# frozen_string_literal: true

require 'spec_helper'

describe Restify::Resource do
  subject(:resource) { described_class.new(context, response:, data:, relations:) }

  let(:data)      { {} }
  let(:relations) { {} }
  let(:context)   { instance_double(Restify::Context) }
  let(:response)  { instance_double(Restify::Response) }

  context 'relations' do
    let(:relations) do
      {
        'users' => 'http://example.org/users',
        'projects' => 'http://example.org/projects',
      }
    end

    describe '#relation?' do
      it 'matches relations' do
        expect(resource.relation?(:users)).to be true
        expect(resource.relation?('users')).to be true
        expect(resource.relation?(:projects)).to be true
        expect(resource.relation?('projects')).to be true
        expect(resource.relation?('fuu')).to be false

        expect(resource).to have_relation :users
        expect(resource).to have_relation :projects

        expect(resource.rel?(:users)).to be true
        expect(resource.rel?('users')).to be true
        expect(resource.rel?(:projects)).to be true
        expect(resource.rel?('projects')).to be true
        expect(resource.rel?('fuu')).to be false

        expect(resource).to have_rel :users
        expect(resource).to have_rel :projects
      end
    end

    describe '#relation' do
      it 'returns relation' do
        expect(resource.rel(:users)).to be_a Restify::Relation

        expect(resource.rel(:users)).to eq 'http://example.org/users'
        expect(resource.rel('users')).to eq 'http://example.org/users'
        expect(resource.rel(:projects)).to eq 'http://example.org/projects'
        expect(resource.rel('projects')).to eq 'http://example.org/projects'
        expect { resource.rel(:fuu) }.to raise_error KeyError

        expect(resource.relation(:users)).to eq 'http://example.org/users'
        expect(resource.relation('users')).to eq 'http://example.org/users'
        expect(resource.relation(:projects)).to eq 'http://example.org/projects'
        expect(resource.relation('projects')).to eq 'http://example.org/projects'
        expect { resource.relation(:fuu) }.to raise_error KeyError
      end
    end

    describe '#follow' do
      let(:relations) { {_restify_follow: 'http://localhost/10'} }

      it 'returns follow relation' do
        expect(resource.follow).to be_a Restify::Relation
        expect(resource.follow).to eq 'http://localhost/10'
      end

      context 'when nil' do
        let(:relations) { {} }

        it 'returns nil' do
          expect(resource.follow).to be_nil
        end
      end
    end

    describe '#follow!' do
      let(:relations) { {_restify_follow: 'http://localhost/10'} }

      it 'returns follow relation' do
        expect(resource.follow!).to be_a Restify::Relation
        expect(resource.follow!).to eq 'http://localhost/10'
      end

      context 'when nil' do
        let(:relations) { {} }

        it 'raise runtime error' do
          expect { resource.follow! }.to raise_error RuntimeError do |err|
            expect(err.message).to eq 'Nothing to follow'
          end
        end
      end
    end
  end

  context 'data' do
    let(:data) { double 'data' } # rubocop:disable RSpec/VerifiedDoubles

    it 'delegates methods (I)' do
      allow(data).to receive(:some_method).and_return(42)

      expect(resource).to respond_to :some_method
      expect(resource.some_method).to eq 42
    end

    it 'delegates methods (II)' do
      allow(data).to receive(:[]).with(1).and_return(2)

      expect(resource).to respond_to :[]
      expect(resource[1]).to eq 2
    end

    describe '#data' do
      it 'returns data' do
        expect(resource.data).to equal data
      end
    end
  end
end
