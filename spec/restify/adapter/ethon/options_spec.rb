# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon::Options do
  subject(:options) { described_class.new(values) }

  def number(name)
    described_class.number(name)
  end

  describe '#to_a' do
    subject(:compiled) { options.to_a }

    context 'with bool options' do
      let(:values) { {followlocation: true, verbose: false, tcp_keepalive: 0} }

      it 'converts to 1 or 0' do
        expect(compiled).to eq [
          [number(:followlocation), :long, 1],
          [number(:verbose), :long, 0],
          [number(:tcp_keepalive), :long, 0],
        ]
      end
    end

    context 'with int options' do
      let(:values) { {timeout_ms: 1500, maxredirs: '5'} }

      it { expect(compiled).to eq [[number(:timeout_ms), :long, 1500], [number(:maxredirs), :long, 5]] }
    end

    context 'with enum options' do
      let(:values) { {sslversion: :tlsv1, proxytype: 'https', timecondition: 1} }

      it 'converts symbols, strings, and numbers' do
        expect(compiled).to eq [
          [number(:sslversion), :long, 1],
          [number(:proxytype), :long, 2],
          [number(:timecondition), :long, 1],
        ]
      end
    end

    context 'with bitmask options' do
      let(:values) { {protocols: %i[http https], redir_protocols: :https} }

      it { expect(compiled).to eq [[number(:protocols), :long, 3], [number(:redir_protocols), :long, 2]] }
    end

    context 'with string options' do
      let(:values) { {useragent: :restify} }

      it { expect(compiled).to eq [[number(:useragent), :string, 'restify']] }
    end

    context 'with nil values' do
      let(:values) { {useragent: nil, timeout_ms: 5} }

      it { expect(compiled).to eq [[number(:timeout_ms), :long, 5]] }
    end

    context 'with other option types' do
      let(:values) { {postquote: []} }

      it 'uses the generic handling' do
        expect(compiled).to eq [[:postquote, nil, []]]
      end
    end
  end

  describe '#initialize' do
    it 'raises on unknown options' do
      expect { described_class.new(unknown: 1) }.to raise_error ArgumentError, /Unknown libcurl option: unknown/
    end

    it 'raises on unknown values' do
      expect { described_class.new(sslversion: :tlsv9) }.to raise_error ArgumentError, /sslversion: :tlsv9/
    end
  end

  describe '#apply' do
    let(:values) { {followlocation: true, useragent: 'restify', postquote: []} }
    let(:easy) { instance_double(Restify::Adapter::Ethon::Easy, handle: FFI::Pointer.new(1)) }

    it 'sets converted options directly, and others with the generic handling' do
      expect(Ethon::Curl).to receive(:easy_setopt).with(easy.handle, number(:followlocation), :long, 1)
      expect(Ethon::Curl).to receive(:easy_setopt).with(easy.handle, number(:useragent), :string, 'restify')
      expect(Ethon::Curl).to receive(:set_option).with(:postquote, [], easy.handle)

      options.apply(easy)
    end
  end

  describe '.number' do
    it 'returns the number of the libcurl option' do
      expect(number(:timeout_ms)).to eq 155
    end

    it 'raises on unknown options' do
      expect { number(:unknown) }.to raise_error ArgumentError, /Unknown libcurl option/
    end
  end
end
