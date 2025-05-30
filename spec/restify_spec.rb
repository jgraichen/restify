# frozen_string_literal: true

require 'spec_helper'

describe Restify do
  context 'as a dynamic HATEOAS client' do
    before do
      stub_request(:get, 'http://stubserver/base').to_return do
        <<~HTTP
          HTTP/1.1 200 OK
          Content-Type: application/json
          Link: <http://localhost:9292/base/users{/id}>; rel="users"
          Link: <http://localhost:9292/base/courses{/id}>; rel="courses"

          {
            "profile_url": "http://localhost:9292/base/profile",
            "search_url": "http://localhost:9292/base/search?q={query}",
            "mirror_url": null
          }
        HTTP
      end

      stub_request(:get, 'http://stubserver/base/users')
        .to_return do
        <<~HTTP
          HTTP/1.1 200 OK
          Content-Type: application/json

          [{
            "name": "John Smith",
            "url": "http://localhost:9292/base/users/john.smith",
            "blurb_url": "http://localhost:9292/base/users/john.smith/blurb",
            "languages": ["de", "en"]
          },
          {
            "name": "Jane Smith",
            "self_url": "http://localhost:9292/base/user/jane.smith"
          }]
        HTTP
      end

      stub_request(:post, 'http://stubserver/base/users')
        .with(body: {})
        .to_return do
        <<~HTTP
          HTTP/1.1 422 Unprocessable Entity
          Content-Type: application/json

          {"errors":{"name":["can't be blank"]}}
        HTTP
      end

      stub_request(:post, 'http://stubserver/base/users')
        .with(body: {name: 'John Smith'})
        .to_return do
        <<~HTTP
          HTTP/1.1 201 Created
          Content-Type: application/json
          Location: http://localhost:9292/base/users/john.smith

          {
            "name": "John Smith",
            "url": "http://localhost:9292/base/users/john.smith",
            "blurb_url": "http://localhost:9292/base/users/john.smith/blurb",
            "languages": ["de", "en"]
          }
        HTTP
      end

      stub_request(:get, 'http://stubserver/base/users/john.smith')
        .to_return do
        <<~HTTP
          HTTP/1.1 200 OK
          Content-Type: application/json
          Link: <http://localhost:9292/base/users/john.smith>; rel="self"

          {
            "name": "John Smith",
            "url": "http://localhost:9292/base/users/john.smith"
          }
        HTTP
      end

      stub_request(:get, 'http://stubserver/base/users/john.smith/blurb')
        .to_return do
        <<~HTTP
          HTTP/1.1 200 OK
          Content-Type: application/json
          Link: <http://localhost:9292/base/users/john.smith>; rel="user"

          {
            "title": "Prof. Dr. John Smith",
            "image": "http://example.org/avatar.png"
          }
        HTTP
      end
    end

    context 'within threads' do
      it 'consumes the API' do
        # Let's get all users

        # First request the entry resource usually the
        # root using GET and wait for it.
        root = Restify.new('http://localhost:9292/base').get.value!

        # Therefore we need the `users` relations of our root
        # resource.
        users_relation = root.rel(:users)

        # The relation is a `Restify::Relation` and provides
        # method to enqueue e.g. GET or POST requests with
        # parameters to fill in possible URI template placeholders.
        expect(users_relation).to be_a Restify::Relation

        # Let's create a user first.
        # This method returns instantly and returns a `Promise`.
        # This `Promise` represents the future value.
        # We can pass parameters to a request. They will be used
        # to expand the URI template behind the relation. Additional
        # fields will be encoding in e.g. JSON and send if not a GET
        # request.
        create_user_promise = users_relation.post
        expect(create_user_promise).to be_a Restify::Promise

        # We can do other things while the request is processed in
        # the background. When we need the response with can call
        # {#value} on the promise that will block the thread until
        # the result is here.
        expect { create_user_promise.value! }.to \
          raise_error(Restify::ClientError) do |e|
          # Because we forgot to send a "name" the server complains
          # with an error code that will lead to a raised error.

          expect(e.status).to eq :unprocessable_content
          expect(e.code).to eq 422
          expect(e.errors).to eq 'name' => ["can't be blank"]
        end

        # Let's try again.
        created_user = users_relation.post({name: 'John Smith'}).value!

        # The server returns a 201 Created response with the created
        # resource.
        expect(created_user.response.status).to eq :created
        expect(created_user.response.code).to eq 201

        expect(created_user).to have_key 'name'
        expect(created_user['name']).to eq 'John Smith'

        # Let's follow the "Location" header.
        followed_resource = created_user.follow.get.value!

        expect(followed_resource.response.status).to eq :ok
        expect(followed_resource.response.code).to eq 200

        expect(followed_resource).to have_key 'name'
        expect(followed_resource['name']).to eq 'John Smith'

        # Now we will fetch a list of all users.
        users = users_relation.get.value!

        # We get a collection back (Restify::Collection).
        expect(users).to have(2).items

        # Let's get the first one.
        user = users.first

        # We have all our attributes and relations here as defined in the
        # responses from the server.
        expect(user).to have_key 'name'
        expect(user['name']).to eq 'John Smith'
        expect(user).to have_relation :self
        expect(user).to have_relation :blurb

        # Let's get the blurb.
        blurb = user.rel(:blurb).get.value!

        expect(blurb).to have_key 'title'
        expect(blurb).to have_key 'image'

        expect(blurb['title']).to eq 'Prof. Dr. John Smith'
        expect(blurb['image']).to eq 'http://example.org/avatar.png'
      end
    end
  end
end
