require 'spec_helper'

describe Restify do

  context 'as a dynamic HATEOAS client' do
    before do
      stub_request(:get, 'http://localhost/base').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Transfer-Encoding: chunked
          Link: <http://localhost/base/users{/id}>; rel="users"
          Link: <http://localhost/base/courses{/id}>; rel="courses"

          {
            "profile_url": "http://localhost/base/profile",
            "search_url": "http://localhost/base/search?q={query}{&page,per_page}"
          }
        EOF
      end

      stub_request(:get, 'http://localhost/base/users').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Transfer-Encoding: chunked

          [{
             "name": "John Smith",
             "url": "http://localhost/base/users/john.smith",
             "blurb_url": "http://localhost/base/users/john.smith/blurb"
           },
           {
             "name": "Jane Smith",
             "self_url": "http://localhost/base/user/jane.smith"
           }]
        EOF
      end

      stub_request(:get, 'http://localhost/base/users/john.smith/blurb').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/json
          Link: <http://localhost/base/users/john.smith>; rel="user"
          Transfer-Encoding: chunked

          {
            "title": "Prof. Dr. John Smith",
            "image": "http://example.org/avatar.png"
          }
        EOF
      end
    end

    let(:c) do
      Restify.new('http://localhost/base').value
    end

    it 'should consume the API' do
      users = c.rel(:users).get
      expect(users).to be_a Obligation

      users = users.value
      expect(users).to have(2).items

      user = users.first
      expect(user).to have_key :name
      expect(user[:name]).to eq 'John Smith'
      expect(user).to have_relation :self
      expect(user).to have_relation :blurb

      blurb_rel = user.rel(:blurb)

      blurb_promise = blurb_rel.get
      expect(blurb_promise).to be_a Obligation

      blurb = blurb_promise.value

      expect(blurb).to have_key :title
      expect(blurb).to have_key :image

      expect(blurb[:title]).to eq 'Prof. Dr. John Smith'
      expect(blurb[:image]).to eq 'http://example.org/avatar.png'
    end
  end
end
