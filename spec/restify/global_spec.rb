# frozen_string_literal: true

require 'spec_helper'

describe Restify::Global do
  let(:global) { Restify }

  describe '#new' do
    context 'with string URI' do
      subject { global.new uri, **options }

      let(:uri)     { 'http://api.github.com/' }
      let(:options) { {accept: 'application.vnd.github.v3+json'} }

      it 'returns relation for URI' do
        expect(subject).to be_a Restify::Relation
        expect(subject.pattern).to eq uri
        expect(subject.context.uri.to_s).to eq uri
        expect(subject.context.options).to eq options
      end
    end

    context 'with registry symbol' do
      subject { global.new(name, **options) }

      let(:name) { :registry_item_name }
      let(:uri)     { 'http://api.github.com/' }
      let(:options) { {accept: 'application.vnd.github.v3+json'} }
      let(:context) { Restify::Context.new uri, **options }

      it 'returns relation for stored registry item' do
        Restify::Registry.store(name, uri, **options)

        expect(subject).to be_a Restify::Relation
        expect(subject.pattern).to eq uri
        expect(subject.context.uri.to_s).to eq uri
        expect(subject.context.options).to eq options
      end
    end
  end
end
