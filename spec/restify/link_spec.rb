require 'spec_helper'

describe Restify::Link do
  describe 'class' do
    describe '#parse' do
      it 'should parse link with quotes' do
        links = described_class
                .parse('<http://example.org/search{?query}>; rel="search"')

        expect(links).to have(1).item
        expect(links[0].uri).to eq 'http://example.org/search{?query}'
        expect(links[0].metadata).to eq 'rel' => 'search'
      end

      it 'should parse link without quotes' do
        links = described_class
                .parse('<http://example.org/search{?query}>; rel=search')

        expect(links).to have(1).item
        expect(links[0].uri).to eq 'http://example.org/search{?query}'
        expect(links[0].metadata).to eq 'rel' => 'search'
      end

      it 'should parse multiple links' do
        links = described_class
                .parse('<p://h.tld/p>; rel=abc, <p://h.tld/b>; a=b; c="d"')

        expect(links).to have(2).item
        expect(links[0].uri).to eq 'p://h.tld/p'
        expect(links[0].metadata).to eq 'rel' => 'abc'
        expect(links[1].uri).to eq 'p://h.tld/b'
        expect(links[1].metadata).to eq 'a' => 'b', 'c' => 'd'
      end

      it 'should parse link w/o meta' do
        links = described_class.parse('<p://h.tld/b>')

        expect(links[0].uri).to eq 'p://h.tld/b'
      end

      it 'should parse on invalid URI' do
        links = described_class.parse('<hp://:&*^/fwbhg3>')

        expect(links[0].uri).to eq 'hp://:&*^/fwbhg3'
      end

      it 'should error on invalid header' do
        expect { described_class.parse('</>; rel="s", abc-invalid') }
          .to raise_error ArgumentError, /Invalid token at \d+:/i
      end
    end
  end
end
