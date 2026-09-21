# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  # Restify follows relations from URLs in server responses, and libcurl
  # supports far more than HTTP. A server must therefore never be able
  # to make it access e.g. a `file://` or `gopher://` URL.
  describe 'Protocol restrictions' do
    subject(:request) { Restify.new(uri).get.value! }

    context 'with a file URI' do
      let(:uri) { "file://#{File.expand_path(__FILE__)}" }

      it 'refuses the request' do
        expect { request }.to raise_error Restify::NetworkError, /protocol/i
      end
    end

    context 'with a gopher URI' do
      let(:uri) { 'gopher://localhost:70/1' }

      it 'refuses the request' do
        expect { request }.to raise_error Restify::NetworkError, /protocol/i
      end
    end
  end
end
