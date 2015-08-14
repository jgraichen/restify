require 'spec_helper'

describe Restify::Resource do
  let(:data)      { {} }
  let(:relations) { {} }
  let(:context)   { double 'context' }
  let(:response)  { double 'response' }
  let(:resource)  { described_class.new(context, response: response, data: data, relations: relations) }
  subject { resource }

  before do
    allow(context).to receive(:relation?).and_return(false)
    allow(context).to receive(:relation).and_raise(KeyError)
  end

  context 'relations' do
    let(:relations) do
      {
        'users' => 'http://example.org/users',
        'projects' => 'http://example.org/projects'
      }
    end

    describe '#relation?' do
      it 'should match relations' do
        expect(subject.relation?(:users)).to eq true
        expect(subject.relation?('users')).to eq true
        expect(subject.relation?(:projects)).to eq true
        expect(subject.relation?('projects')).to eq true
        expect(subject.relation?('fuu')).to eq false

        expect(subject).to have_relation :users
        expect(subject).to have_relation :projects

        expect(subject.rel?(:users)).to eq true
        expect(subject.rel?('users')).to eq true
        expect(subject.rel?(:projects)).to eq true
        expect(subject.rel?('projects')).to eq true
        expect(subject.rel?('fuu')).to eq false

        expect(subject).to have_rel :users
        expect(subject).to have_rel :projects
      end
    end

    describe '#relation' do
      it 'should return relation' do
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

    context '#follow' do
      let(:relations) { {_restify_follow: 'http://localhost/10'} }

      it 'returns follow relation' do
        expect(subject.follow).to be_a Restify::Relation
        expect(subject.follow).to eq 'http://localhost/10'
      end
    end
  end

  context 'data' do
    let(:data) { double 'data' }

    it 'should delegate methods (I)' do
      expect(data).to receive(:some_method).and_return(42)

      expect(subject).to respond_to :some_method
      expect(subject.some_method).to eq 42
    end

    it 'should delegate methods (II)' do
      expect(data).to receive(:[]).with(1).and_return(2)

      expect(subject).to respond_to :[]
      expect(subject[1]).to eq 2
    end
  end
end
