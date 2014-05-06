require 'spec_helper'

describe Restify::Resource do
  let(:res) { described_class.new }

  describe '#rel?' do
    before do
      res.relations['users']   = true
      res.relations[:projects] = true
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
    let(:users) { double 'users rel' }
    let(:projects) { double 'projects rel' }
    before do
      res.relations['users']   = users
      res.relations[:projects] = projects
    end

    it 'should return relation' do
      expect(res.rel(:users)).to eq users
      expect(res.rel('users')).to eq users
      expect(res.rel(:projects)).to eq projects
      expect(res.rel('projects')).to eq projects
      expect { res.rel(:fuu) }.to raise_error KeyError

      expect(res.relation(:users)).to eq users
      expect(res.relation('users')).to eq users
      expect(res.relation(:projects)).to eq projects
      expect(res.relation('projects')).to eq projects
      expect { res.relation(:fuu) }.to raise_error KeyError
    end
  end

  describe '#key?' do
    before { res.data.merge! a: 0, 'b' => 1, 0 => 2 }

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
    before { res.data.merge! a: 0, b: 1 }

    it 'should yield' do
      expect { |cb| res.each(&cb) }.to yield_control.twice
      expect { |cb| res.each(&cb) }.to yield_successive_args ['a', 0], ['b', 1]
    end

    it 'should return enumerator' do
      expect(res.each).to be_a Enumerator
      expect(res.each.to_a).to eq [['a', 0], ['b', 1]]
    end
  end
end
