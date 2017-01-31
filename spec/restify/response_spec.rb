require 'spec_helper'

describe Restify::Response do
  let(:request) { double('request') }
  let(:uri) { double('uri') }
  let(:code) { 200 }
  let(:headers) { {} }
  let(:body) { '' }
  let(:response) { described_class.new(request, uri, code, headers, body) }

  context '#headers' do
    subject { response.headers }

    it 'includes current Date if not set' do
      expect(subject).to include 'DATE' => Time.now.httpdate
    end
  end
end
