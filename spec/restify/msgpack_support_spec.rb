# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  describe 'when receiving MessagePack representations' do
    before do
      # Body maps to {"company":true,"schema":0,"subs_url":"http://localhost/base/subs"}
      msgpack_body = [
        '83a7636f6d70616e79c3a6736368656d6100a8737562735f75726cba687474703a2f2f6c6f63616c686f73742f626173652f73756273'
      ].pack('H*')
      stub_request(:get, 'http://localhost/base').to_return do
        <<-EOF.gsub(/^ {10}/, '').rstrip.gsub('BODY', msgpack_body)
          HTTP/1.1 200 OK
          Content-Type: application/msgpack
          Link: <http://localhost/base/users{/id}>; rel="users"
          Link: <http://localhost/base/courses{/id}>; rel="courses"

          BODY
        EOF
      end
    end

    it 'understands the API response' do
      # msgpack has to be included manually when using Restify to parse
      # MessagePack representations.
      require 'msgpack'

      root = Restify.new('http://localhost/base').get.value!

      expect(root).to have_key 'company'
      expect(root).to have_key 'schema'
      expect(root.company).to eq true
      expect(root.schema).to eq 0

      # Link header relations should be parsed as usual
      users_relation = root.rel(:users)
      expect(users_relation).to be_a Restify::Relation

      # Fields ending in _url are parsed as relation as well
      expect(root).to have_relation 'subs'
    end
  end
end
