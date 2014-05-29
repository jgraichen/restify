# Restify

Restify is a experimental hypermedia REST client that uses parallel, keep-alive and pipelined requests by default.

Restify scans Link headers and returned resource for links and relations to other resources, represented as RFC6570 URI Templates, and exposes those to the developer.

Restify can be used to consume hyper-media REST APIs (like GitHubs), to build a site-specific library or to use within your own backend services.

Restify is build upon

* [obligation](https://github.com/jgraichen/obligation)
* [addressable](https://github.com/sporkmonger/addressable)

provided HTTP adapters for

* [em-http-request](https://github.com/igrigorik/em-http-request)

and can decode and encode

* [JSON](https://github.com/intridea/multi_json)

## Restify is still pre-alpha!

* It does not cover all HTTP methods (not even all basic ones)
* It is build on pre-alpha obligation library.
* It has to less tests.

Planned features:

* Content-Type and Language negotiation
* Encode and decode MessagePack
* ZeroMQ FLP backend
* Eventmachine integration (see obligation library)
* Alternative HTTP backends

## Installation

Add it to your Gemfile or install it manually: `$ gem install restify`

## Usage

Create new Restify object (actually returns '/' resource):

```ruby
client = Restify.new('http://api.github.com').value
```

The `value` call resolves the returned `Obligation` (like a Future object) by blocking the thread until the resource is there.

Get a relation described by the root resource. Restify supports Link headers as well as JSON encoded relations (`*_url` fields).

```
repositories = gh.rel(:repository)
```

Send a GET request for a specific repository using given parameters. They will be used to expand the URI template behind the `repositories` relation.

```
repo = repositories.get(owner: 'jgraichen', repo: 'restify').value
```

Now fetch a list of commits for this repo and get this first one:

```
commit = repo.rel(:commits).get.value.first
```

And print it:

```
puts "Last commit: #{commit[:sha]}"
puts "By #{commit[:commit][:author][:name]} <#{commit[:commit][:author][:email]}>"
puts "#{commit[:commit][:message]}"
```

See commented example in main spec [`spec/restify_spec.rb`](https://github.com/jgraichen/restify/blob/master/spec/restify_spec.rb#L100) or in the `examples` directory.

## Contributing

1. Fork it ( http://github.com/jgraichen/restify/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit specs for your feature so that I do not break it later
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

## License

Copyright (C) 2014 Jan Graichen

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
