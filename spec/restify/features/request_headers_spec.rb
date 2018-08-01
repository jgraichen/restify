# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  let!(:request_stub) do
    stub_request(:get, 'http://localhost/base').to_return do
      <<-EOF.gsub(/^ {8}/, '')
        HTTP/1.1 200 OK
        Content-Type: application/json
        Transfer-Encoding: chunked
        Link: <http://localhost/base>; rel="self"

        { "response": "success" }
      EOF
    end
  end

  context 'with request headers configured for context' do
    let(:context) do
      Restify.new(
        'http://localhost/base',
        headers: {'Accept' => 'application/msgpack, application/json'}
      )
    end

    it 'sends the headers with each request' do
      root = context.get.value!

      root.rel(:self).get.value!

      expect(
        request_stub.with(headers: {'Accept' => 'application/msgpack, application/json'})
      ).to have_been_requested.twice
    end
  end
end
