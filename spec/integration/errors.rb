require 'spec_helper'

describe Restify do
  context 'client error' do
    before do
      stub_request(:get, 'http://localhost/').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 422 Unprocessable Entity
          Content-Type: application/json
          Transfer-Encoding: chunked

          {
            "message": "Resource is invalid",
            "errors": {
              "name": ["invalid"]
            }
          }
        EOF
      end
    end

    let(:request) { Restify.new('http://localhost/').get }

    context '#value' do
      subject { request.value }

      it 'returns error resource' do
        is_expected.to eq \
          'message' => 'Resource is invalid',
          'errors' => {'name' => ['invalid']}

        expect(subject.response.code).to eq 422
        expect(subject.response.status).to eq :unprocessable_entity
      end
    end

    context '#value!' do
      subject { -> { request.value! } }

      it 'raises client error' do
        is_expected.to raise_error(Restify::ClientError) do |error|

        end
      end
    end
  end
end
