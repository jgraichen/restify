# Restify

Restify is an experimental hypermedia REST client that uses parallel, keep-alive and pipelined requests by default.

Restify scans Link headers and returned resource for links and relations to other resources, represented as RFC6570 URI Templates, and exposes those to the developer.

Restify can be used to consume hypermedia REST APIs (like GitHubs), to build a site-specific library or to use within your own backend services.

Restify is build upon the following libraries:

* [obligation](https://github.com/jgraichen/obligation)
* [addressable](https://github.com/sporkmonger/addressable)

It provides HTTP adapters to use with:

* [em-http-request](https://github.com/igrigorik/em-http-request)
* [celluloid-io](https://github.com/celluloid/celluloid-io) / [http](https://github.com/httprb/http) (experimental)
* [typhoeus](https://github.com/typhoeus/typhoeus) (new default)

They are mostly run in a background thread and may not survive mid-application forks.

Included processors can handle:

* Plain JSON with GitHub-Style relations

(Beside HTTP Link header that's always supported)

Restify requires Ruby 2.0+.

## Restify is still under development

* It is build on experimental obligation library.

Planned features:

* API versions via header
* Content-Type and Language negotiation
* Processors for MessagePack, JSON-HAL, etc.
* Eventmachine integration (see obligation library)

## Installation

Add it to your Gemfile or install it manually: `$ gem install restify`

## Usage

Create new Restify object. It essentially means to request some start-resource usually the "root" resource:

```ruby
client = Restify.new('https://api.github.com').get.value
# => {"current_user_url"=>"https://api.github.com/user",
#     "current_user_authorizations_html_url"=>"https://github.com/settings/connections/applications{/client_id}",
# ...
#     "repository_url"=>"https://api.github.com/repos/{owner}/{repo}",
# ...
```

We are essentially requesting `'http://api.github.com'` via HTTP `get`. `get` is returning an `Obligation`, similar to Java's `Future`. The `value` call resolves the returned `Obligation` by blocking the thread until the resource is actually there.

As we can see GitHub returns us a field `repository_url` with a URI template. Restify automatically scans for `*_url` fields in the JSON response and exposes these as relations. It additionally scans the HTTP Header field `Link` for relations like pagination.

We can now use the relations to navigate from resource to resource like a browser from one web page to another page.

```ruby
repositories = client.rel(:repository)
# => #<Restify::Relation:0x00000005548968 @context=#<Restify::Context:0x007f6024066ae0 @uri=#<Addressable::URI:0x29d8684 URI:https://api.github.com>>, @template=#<Addressable::Template:0x2aa44a0 PATTERN:https://api.github.com/repos/{owner}/{repo}>>
```

This gets us the relation named `repository` that we can request now. The usual HTTP methods are available on a relation:

```ruby
    def get(params = {})
      request :get, nil, params
    end

    def delete(params = {})
      request :delete, nil, params
    end

    def post(data = {}, params = {})
      request :post, data, params
    end

    def put(data = {}, params = {})
      request :put, data, params
    end

    def patch(data = {}, params = {})
      request :patch, data, params
    end
```

URL templates can define some parameters such as `{owner}` or `{repo}`. They will be expanded from the `params` given to the HTTP method method.

Now send a GET request with some parameters to request a specific repository:

```ruby
repo = repositories.get(owner: 'jgraichen', repo: 'restify').value
```

Now fetch a list of commits for this repo and get this first one:

```ruby
commit = repo.rel(:commits).get.value.first
```

And print it:

```ruby
puts "Last commit: #{commit[:sha]}"
puts "By #{commit[:commit][:author][:name]} <#{commit[:commit][:author][:email]}>"
puts "#{commit[:commit][:message]}"
```

See commented example in main spec [`spec/restify_spec.rb`](https://github.com/jgraichen/restify/blob/master/spec/restify_spec.rb#L100) or in the `examples` directory.

## Contributing

1. [Fork it](http://github.com/jgraichen/restify/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit specs for your feature so that I do not break it later
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

## License

Copyright (C) 2014-2015 Jan Graichen

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
