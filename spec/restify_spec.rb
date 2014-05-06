require 'spec_helper'

describe Restify do

  context 'as a dynamic HATEOAS client' do
    before do
      stub_request(:get, 'http://srv/base').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/vnd.myapp+json; charset=utf-8
          Transfer-Encoding: chunked
          Link: <http://srv/base/users{/id}>; rel="users"
          Link: <http://srv/base/courses{/id}>; rel="courses"

          {
            "profile_url": "http://srv/base/profile",
            "search_url": "http://srv/base/search?q={query}{&page,per_page}"
          }
        EOF
      end

      stub_request(:get, 'http://srv/base/users').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/vnd.myapp+json; charset=utf-8
          Transfer-Encoding: chunked

          [{"user": {
             "name": "John Smith",
             "url": "http://srv/base/user/john.smith"
             "blurb_url": "http://srv/base/user/john.smith/blurb"
           }},
           {"user": {
             "name": "Jane Smith",
             "self_url": "http://srv/base/user/jane.smith"
           }}]
        EOF
      end

      stub_request(:get, 'http://srv/base/users/john.smith/blurb').to_return do
        <<-EOF.gsub(/^ {10}/, '')
          HTTP/1.1 200 OK
          Content-Type: application/vnd.myapp+json; charset=utf-8
          Link: <http://srv/base/users/john.smith>; rel="user"
          Transfer-Encoding: chunked

          {
            "title": "Prof. Dr. John Smith",
            "image": "http://example.org/avatar.png"
          }
        EOF
      end
    end

    let(:c) do
      Restify.new('http://srv/base').value
    end

    it 'should consume the API' do
      users = c.rel(:users).get
      expect(users).to be_a Obligation

      users = users.value
      expect(users).to have(2).items

      user = users.first
      expect(user).to include name: 'John Smith'
      expect(user).to have_relation :self
      expect(user).to have_relation :blurb

      blurb_promise = user.rel(:blurb)
      expect(blurb_promise).to be_a Obligation

      blurb = nil
      blurb_promise.then do |b|
        blurb = b
      end

      blurb.value

      expect(blurb).to include title: 'Prof. Dr. John Smith'
      expect(blurb).to include image: 'http://example.org/avatar.png'
      expect(blurb).to have_relation :user
      expect(blurb.rel_url(:user)).to eq 'http://srv/base/users/john.smith'
    end
  end
end
