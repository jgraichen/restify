# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  subject(:resource) { Restify.new('http://localhost:9292/old/resource').get.value! }

  before do
    stub_request(:get, 'http://stubserver/old/resource')
      .to_return do
      <<~HTTP
        HTTP/1.1 302 Found
        Location: http://localhost:9292/new/resource

      HTTP
    end

    stub_request(:get, 'http://stubserver/new/resource')
      .to_return do
      <<~HTTP
        HTTP/1.1 200 OK
        Content-Type: application/json

        {"name":"John Smith","sibling_url":"./sibling"}
      HTTP
    end
  end

  describe 'following redirects' do
    it 'returns the redirected resource' do
      expect(resource['name']).to eq 'John Smith'
      expect(resource.response.code).to eq 200
    end

    it 'exposes the effective URI on the response' do
      expect(resource.response.uri.to_s)
        .to eq 'http://localhost:9292/new/resource'
    end

    it 'resolves relative relations against the effective URI' do
      expect(resource.rel(:sibling).expand({}).to_s)
        .to eq 'http://localhost:9292/new/sibling'
    end
  end
end
