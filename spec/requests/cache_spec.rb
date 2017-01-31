require 'spec_helper'

describe 'Restify cache' do
  let(:request) { Restify.new('http://localhost/request') }

  before { Restify.cache.clear }
  before { Timecop.freeze }
  after { Timecop.return }

  context 'without Cache-Control' do
    let!(:mock) do
      stub_request(:get, 'http://localhost/request').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Transfer-Encoding: chunked

          "abc-test"
        EOF
      end
    end

    it 'caches simple public response' do
      expect(request.get.value!).to eq 'abc-test'
      expect(request.get.value!).to eq 'abc-test'

      expect(mock).to have_been_made.twice
    end
  end

  context 'Cache-Control: public' do
    let!(:mock) do
      stub_request(:get, 'http://localhost/request').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Transfer-Encoding: chunked
          Cache-Control: public, max-age=30

          "abc-test"
        EOF
      end
    end

    it 'caches simple public response' do
      expect(request.get.value!).to eq 'abc-test'
      expect(request.get.value!).to eq 'abc-test'

      expect(mock).to have_been_requested.twice
    end
  end

  context 'Cache-Control: private' do
    let!(:mock) do
      stub_request(:get, 'http://localhost/request').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Transfer-Encoding: chunked
          Cache-Control: private, max-age=30

          "abc-test"
        EOF
      end
    end

    it 'caches simple public response' do
      expect(request.get.value!).to eq 'abc-test'
      expect(request.get.value!).to eq 'abc-test'

      expect(mock).to have_been_requested.twice
    end
  end
end
