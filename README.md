# Restify

[![Gem Version](https://img.shields.io/gem/v/restify?logo=ruby)](https://rubygems.org/gems/restify)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/jgraichen/restify/test.yml?logo=github)](https://github.com/jgraichen/restify/actions)
[![Code Quality](https://codebeat.co/badges/368f8033-bd76-48bc-9777-85f1d4befa94)](https://codebeat.co/projects/github-com-jgraichen-restify-main)

Restify is an hypermedia REST client that does parallel, concurrent and keep-alive requests by default.

Restify scans Link headers and returned resource for links and relations to other resources, represented as RFC6570 URI Templates, and exposes those to the developer.

Restify can be used to consume hypermedia REST APIs (like GitHubs), to build a site-specific library or to use within your own backend services.

Restify is build upon the following libraries:

* [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby)
* [addressable](https://github.com/sporkmonger/addressable)
* [typhoeus](https://github.com/typhoeus/typhoeus)

The HTTP adapters are mostly run in a background thread and may not survive mid-application forks.

Restify includes processors to parse responses and to extract links between resources. The following formats are can be parsed:

* JSON
* MessagePack

Links are extracted from

* HTTP Link header
* Github-style relations in payloads

## Installation

Add it to your Gemfile:

```ruby
gem 'restify', '~> 2.0'
```

Or install it manually:

```console
gem install restify
```

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

We are essentially requesting `'http://api.github.com'` via HTTP `get`. `get` is returning a `Promise`, similar to Java's `Future`. The `value` call resolves the returned `Promise` by blocking the thread until the resource is actually there. `value!` will additionally raise errors instead of returning `nil`. You can chain handlers using the `then` method. This allows you to be build a dependency chain that will be executed when the last promise is needed.

As we can see GitHub returns us a field `repository_url` with a URI template. Restify automatically scans for `*_url` fields in the JSON response and exposes these as relations. It additionally scans the HTTP Header field `Link` for relations like pagination.

We can now use the relations to navigate from resource to resource like a browser from one web page to another page.

```ruby
repositories = client.rel(:repository)
# => #<Restify::Relation:0x00000005548968 @context=#<Restify::Context:0x007f6024066ae0 @uri=#<Addressable::URI:0x29d8684 URI:https://api.github.com>>, @template=#<Addressable::Template:0x2aa44a0 PATTERN:https://api.github.com/repos/{owner}/{repo}>>
```

This gets us the relation named `repository` that we can request now. The usual HTTP methods are available on a relation:

```ruby
def get(params, params:, headers:, **)
def head(params, params:, headers:, **)
def delete(params, params:, headers:, **)

def put(data = nil, params:, headers:, **)
def post(data = nil, params:, headers:, **)
def patch(data = nil, params:, headers:, **)
```

URL templates can define some parameters such as `{owner}` or `{repo}`. They will be expanded from the `params` given to the HTTP method.

Now send a GET request with some parameters to request a specific repository:

```ruby
repo = repositories.get({owner: 'jgraichen', repo: 'restify'}).value
```

Now fetch a list of commits for this repo and get this first one:

```ruby
commit = repo.rel(:commits).get.value.first
```

And print it:

```ruby
puts "Last commit: #{commit['sha']}"
puts "By #{commit['commit']['author']['name']} <#{commit['commit']['author']['email']}>"
puts "#{commit['commit']['message']}"
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

Copyright (C) 2014-2025 Jan Graichen

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
