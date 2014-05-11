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
            "search_url": "http://localhost/base/search?q={query}",
            "mirror_url": null
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

      stub_request(:get, 'http://localhost/base/users/john.smith/blurb')
        .to_return do <<-EOF.gsub(/^ {10}/, '')
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

    context 'within threads' do
      it 'should consume the API' do
        # Let's get all users

        # Therefore we need the `users` relations of our root
        # resource.
        users_relation = c.rel(:users)

        # The relation is a `Restify::Relation` and provides
        # method to enqueue e.g. GET or POST requests with
        # parameters to fill in possible URI template placeholders.
        expect(users_relation).to be_a Restify::Relation

        # Let's fetch users using GET.
        # This method returns instantly and returns an `Obligation`.
        # This `Obligation` represents the future value.
        users_promise = users_relation.get
        expect(users_promise).to be_a Obligation

        # We could do some other stuff - like requesting other
        # resources here - while the users are fetched in the background.
        # When we really need our users we call `#value`. This will block
        # until the users are here.
        users = users_promise.value

        # We get a collection back (Restify::Collection).
        expect(users).to have(2).items

        # Let's get the first one.
        user = users.first

        # We have all our attributes and relations here as defined in the
        # responses from the server.
        expect(user).to have_key :name
        expect(user[:name]).to eq 'John Smith'
        expect(user).to have_relation :self
        expect(user).to have_relation :blurb

        # Let's get the blurb.
        blurb = user.rel(:blurb).get.value

        expect(blurb).to have_key :title
        expect(blurb).to have_key :image

        expect(blurb[:title]).to eq 'Prof. Dr. John Smith'
        expect(blurb[:image]).to eq 'http://example.org/avatar.png'
      end
    end

    context 'within eventmachine' do
      it 'should consume the API' do
        pending

        EventMachine.run do
          users_promise = c.rel(:users).get
          users_promise.then do |users|
            expect(users).to have(2).items

            user = users.first
            expect(user).to have_key :name
            expect(user[:name]).to eq 'John Smith'
            expect(user).to have_relation :self
            expect(user).to have_relation :blurb

            user.rel(:blurb).get.then do |blurb|
              expect(blurb).to have_key :title
              expect(blurb).to have_key :image

              expect(blurb[:title]).to eq 'Prof. Dr. John Smith'
              expect(blurb[:image]).to eq 'http://example.org/avatar.png'

              EventMachine.stop
              @done = true
            end
          end
        end

        expect(@done).to be true
      end
    end
  end
end
