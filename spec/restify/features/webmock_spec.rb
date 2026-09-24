# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  before do
    WebMock.enable!(except: %i[typhoeus])
  end

  after do
    WebMock.disable!(except: %i[net_http])
    WebMock.disable_net_connect!
    WebMock::CallbackRegistry.reset
  end

  describe 'WebMock' do
    subject(:resource) { Restify.new('http://www.example.com/base').get.value! }

    it 'can stub requests' do
      stub_request(:any, 'http://www.example.com/base')

      expect(resource.response.status).to eq(:ok)
    end

    it 'raises error for not stubbed requests' do
      expect { resource }.to raise_error WebMock::NetConnectNotAllowedError
    end

    it 'returns stubbed responses' do
      stub_request(:get, 'http://www.example.com/base')
        .to_return(
          headers: {'Content-Type' => 'application/json', 'X-Custom' => 'yes'},
          body: '{"name": "restify", "self_url": "http://www.example.com/self"}',
        )

      expect(resource['name']).to eq 'restify'
      expect(resource).to have_relation :self
      expect(resource.response.headers).to include('X_CUSTOM' => 'yes')
    end

    it 'records requests' do
      stub_request(:post, 'http://www.example.com/base')

      Restify.new('http://www.example.com/base').post({name: 'restify'}).value!

      expect(
        a_request(:post, 'http://www.example.com/base')
          .with(body: {name: 'restify'}.to_json, headers: {'Content-Type' => 'application/json'}),
      ).to have_been_made.once
    end

    it 'raises network errors on stubbed timeouts' do
      stub_request(:get, 'http://www.example.com/base').to_timeout

      expect { resource }.to raise_error Restify::NetworkError, /timeout/i
    end

    it 'raises stubbed errors' do
      stub_request(:get, 'http://www.example.com/base').to_raise(Errno::ECONNREFUSED)

      expect { resource }.to raise_error Errno::ECONNREFUSED
    end

    it 'creates a span for stubbed requests' do
      stub_request(:get, 'http://www.example.com/base')

      resource

      expect(OTLE_EXPORTER.finished_spans.map {|span| span.instrumentation_scope.name }).to eq ['restify']
    end

    context 'when disabled' do
      it 'does not intercept requests' do
        stub_request(:get, 'http://localhost:9292/echo').to_return(body: 'stubbed')
        WebMock.disable!(except: %i[net_http])

        expect(Restify.new('http://localhost:9292/echo').get.value!.response.body).not_to eq 'stubbed'
      end
    end

    # Like WebMock does for other libcurl-based libraries: Redirects are
    # returned as they are.
    it 'returns stubbed redirects as they are' do
      stub_request(:get, 'http://www.example.com/base')
        .to_return(status: 302, headers: {'Location' => '/other'})

      expect(resource.response.code).to eq 302
      expect(resource.response.headers).to include('LOCATION' => '/other')
      expect(a_request(:get, 'http://www.example.com/other')).not_to have_been_made
    end

    context 'with net connect allowed' do
      before { WebMock.allow_net_connect! }

      it 'passes requests on to the adapter' do
        expect(Restify.new('http://localhost:9292/echo').get.value!.data).to include('REQUEST_METHOD' => 'GET')
      end

      it 'invokes callbacks for real requests once' do
        responses = Queue.new
        WebMock.after_request(real_requests_only: true) do |signature, response|
          responses << [signature.uri.to_s, response.status[0]]
        end

        Restify.new('http://localhost:9292/echo').get.value!

        expect(responses.pop(timeout: 1)).to eq ['http://localhost:9292/echo', 200]
        expect(responses).to be_empty
      end

      it 'records real requests once' do
        Restify.new('http://localhost:9292/echo').get.value!

        expect(a_request(:get, 'http://localhost:9292/echo')).to have_been_made.once
      end
    end
  end
end
