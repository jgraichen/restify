# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:get, 'http://stubserver/base').to_return do
      <<~HTTP
        HTTP/1.1 200 OK
        Content-Type: application/json
        Link: <http://localhost:9292/base>; rel="self"

        { "response": "success" }
      HTTP
    end
  end

  context 'with request headers configured for a single request' do
    let(:context) { Restify.new('http://localhost:9292/base') }

    it 'sends the headers only for that request' do
      root = context.get(
        headers: {'Accept' => 'application/msgpack, application/json'},
      ).value!

      root.rel(:self).get.value!

      expect(request_stub).to have_been_requested.twice
      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json'}),
      ).to have_been_requested.once
    end
  end

  context 'with request headers configured for context' do
    let(:context) do
      Restify.new(
        'http://localhost:9292/base',
        headers: {'Accept' => 'application/msgpack, application/json'},
      )
    end

    it 'sends the headers with each request' do
      root = context.get.value!

      root.rel(:self).get.value!

      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json'}),
      ).to have_been_requested.twice
    end

    it 'can overwrite headers for single requests' do
      root = context.get(
        headers: {'Accept' => 'application/xml'},
      ).value!

      root.rel(:self).get.value!

      expect(
        request_stub.with(headers: {'Accept' => 'application/xml'}),
      ).to have_been_requested.once
      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json'}),
      ).to have_been_requested.once
    end

    it 'can add additional headers for single requests' do
      root = context.get(
        headers: {'X-Custom' => 'foobar'},
      ).value!

      root.rel(:self).get.value!

      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json'}),
      ).to have_been_requested.twice
      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json', 'X-Custom' => 'foobar'}),
      ).to have_been_requested.once
    end
  end
end
