# frozen_string_literal: true

require 'spec_helper'

describe Restify::Link do
  describe 'class' do
    describe '#parse' do
      it 'parses link with quotes' do
        links = described_class
          .parse('<http://example.org/search{?query}>; rel="search"')

        expect(links).to have(1).item
        expect(links[0].uri).to eq 'http://example.org/search{?query}'
        expect(links[0].metadata).to eq 'rel' => 'search'
      end

      it 'parses link without quotes' do
        links = described_class
          .parse('<http://example.org/search{?query}>; rel=search')

        expect(links).to have(1).item
        expect(links[0].uri).to eq 'http://example.org/search{?query}'
        expect(links[0].metadata).to eq 'rel' => 'search'
      end

      it 'parses multiple links' do
        links = described_class
          .parse('<p://h.tld/p>; rel=abc, <p://h.tld/b>; a=b; c="d"')

        expect(links).to have(2).item
        expect(links[0].uri).to eq 'p://h.tld/p'
        expect(links[0].metadata).to eq 'rel' => 'abc'
        expect(links[1].uri).to eq 'p://h.tld/b'
        expect(links[1].metadata).to eq 'a' => 'b', 'c' => 'd'
      end

      it 'parses link w/o meta' do
        links = described_class.parse('<p://h.tld/b>')

        expect(links[0].uri).to eq 'p://h.tld/b'
      end

      it 'parses on invalid URI' do
        links = described_class.parse('<hp://:&*^/fwbhg3>')

        expect(links[0].uri).to eq 'hp://:&*^/fwbhg3'
      end

      it 'errors on invalid header' do
        expect { described_class.parse('</>; rel="s", abc-invalid') }
          .to raise_error ArgumentError, /Invalid token at \d+:/i
      end

      it 'errors on invalid param' do
        expect { described_class.parse('<https://example.org>; rel') }
          .to raise_error ArgumentError, /Invalid token at \d+:/i
      end

      it 'errors on invalid param value' do
        expect { described_class.parse('<https://example.org>; rel=') }
          .to raise_error ArgumentError, /Invalid token at \d+:/i
      end
    end
  end
end
