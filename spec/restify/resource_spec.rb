require 'spec_helper'

describe Restify::Resource do
  let(:client) { double 'client' }
  let(:data) { {} }
  let(:res)    { described_class.new(client, data) }

  describe '#rel?' do
    let(:data) do
      {
        'users_url' => 'http://example.org/users',
        'projects_url' => 'http://example.org/projects',
      }
    end

    it 'should match relations' do
      expect(res.rel?(:users)).to eq true
      expect(res.rel?('users')).to eq true
      expect(res.rel?(:projects)).to eq true
      expect(res.rel?('projects')).to eq true
      expect(res.rel?('fuu')).to eq false

      expect(res).to have_rel :users
      expect(res).to have_rel :projects

      expect(res.relation?(:users)).to eq true
      expect(res.relation?('users')).to eq true
      expect(res.relation?(:projects)).to eq true
      expect(res.relation?('projects')).to eq true
      expect(res.relation?('fuu')).to eq false

      expect(res).to have_relation :users
      expect(res).to have_relation :projects
    end
  end

  describe '#rel' do
    let(:data) do
      {
        'users_url' => 'http://example.org/users',
        'projects_url' => 'http://example.org/projects',
      }
    end

    it 'should return relation' do
      expect(res.rel(:users)).to eq 'http://example.org/users'
      expect(res.rel('users')).to eq 'http://example.org/users'
      expect(res.rel(:projects)).to eq 'http://example.org/projects'
      expect(res.rel('projects')).to eq 'http://example.org/projects'
      expect { res.rel(:fuu) }.to raise_error KeyError

      expect(res.relation(:users)).to eq 'http://example.org/users'
      expect(res.relation('users')).to eq 'http://example.org/users'
      expect(res.relation(:projects)).to eq 'http://example.org/projects'
      expect(res.relation('projects')).to eq 'http://example.org/projects'
      expect { res.relation(:fuu) }.to raise_error KeyError
    end
  end

  describe '#key?' do
    let(:data) { {a: 0, 'b' => 1, 0 => 2} }

    it 'should test for key inclusion' do
      expect(res.key?(:a)).to eq true
      expect(res.key?(:b)).to eq true
      expect(res.key?('a')).to eq true
      expect(res.key?('b')).to eq true
      expect(res.key?(0)).to eq true

      expect(res.key?(:c)).to eq false
      expect(res.key?('d')).to eq false

      expect(res).to have_key :a
      expect(res).to have_key :b
      expect(res).to have_key 'a'
      expect(res).to have_key 'b'
      expect(res).to have_key 0

      expect(res).to_not have_key :c
      expect(res).to_not have_key 'd'
    end
  end

  describe '#each' do
    let(:data) { {a: 0, b: 1} }

    it 'should yield' do
      expect{|cb| res.each(&cb) }.to yield_control.twice
      expect{|cb| res.each(&cb) }.to yield_successive_args ['a', 0], ['b', 1]
    end

    it 'should return enumerator' do
      expect(res.each).to be_a Enumerator
      expect(res.each.to_a).to eq [['a', 0], ['b', 1]]
    end
  end

  describe '#[]' do
    let(:data) { {a: 0, b: 1} }

    it 'should return data' do
      expect(res[:a]).to eq 0
      expect(res[:b]).to eq 1
    end
  end

  describe '<getter>' do
    let(:data) { {a: 0, b: 1} }

    it 'should return data' do
      expect(res).to respond_to :a
      expect(res).to respond_to :b

      expect(res.a).to eq 0
      expect(res.b).to eq 1
    end
  end

  describe '#==' do
    let(:data) { {a: 0, b: 1} }

    it 'should eq hash' do
      expect(res).to eq a: 0, b: 1
      expect(res).to be_eq a: 0, b: 1

      expect(res).to eq 'a' => 0, 'b' => 1
      expect(res).to be_eq 'a' => 0, 'b' => 1
    end
  end

  describe '#include?' do
    let(:data) { {a: 0, b: 1} }

    it 'should include partial hash' do
      expect(res).to include a: 0
      expect(res).to include b: 1

      expect(res).to include 'a' => 0
      expect(res).to include 'b' => 1

      expect(res).to_not include a: 1
      expect(res).to_not include c: 0
      expect(res).to_not include 'a' => 1
      expect(res).to_not include 'c' => 0
    end
  end

  describe '#[]=' do
    let(:data) { {a: 0, b: 1} }

    it 'should return data' do
      res[:a] = 5
      res[:c] = 15

      expect(res[:a]).to eq 5
      expect(res[:b]).to eq 1
      expect(res[:c]).to eq 15
    end
  end
end
