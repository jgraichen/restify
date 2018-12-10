# Changelog

## Unreleased

* Raise more specific error on a few status codes (#17)

## 1.9.0

* Do not raise error on 3XX responses but return responses

## 1.8.0

* Add HEAD request method (#16)

## 1.7.0

* Introduce promise dependency timeouts (#15)

## 1.6.0

* Specify headers on restify clients and individual requests (#14)

## 1.5.0

* Tune typhoeus adapter to be more race-condition resilent
* Add MessagePack processor enabled by default

## 1.4.4

* Fix race condition in typhoeus adapter
* Add `#request` to `NetworkError` to ease debugging

## 1.4.3

* Add advanced logging capabilities using logging gem
* Improve compatibility with webmocks returning `nil` as headers

## 1.4.1

* Fix possible deadlock issues

## 1.4.0

* Fix possible concurrency issue with typhoeus adapter
* Add timeout option to requests (only supported by typhoeus adapter)

## 1.3.1

* Improve typhoeus adapters initial request queuing
* Disable default pipelining

## 1.3.0

* Improve typhoeus adapter to better utilize concurrency
* Default to new typhoeus adapter

## 1.2.1

* Fix issue with Ruby 2.2 compatibility

## 1.2.0

* Add experimental PooledEM adapter (#10)
* Improve marshalling of resources

## 1.1.0

* Return response body if no processor matches (#7)
* Add shortcuts for creating fulfilled / rejected promises (#6)

## 1.0.0

* Experimental cache API doing nothing for now
* Use `~> 1.0` of `concurrent-ruby`

## 0.5.0

* Add `sync` option to typhoeus adapter
* Add registry for storing entry points
* Make eventmachine based adapter default

## 0.4.0

* Add method to explicit access resource data
* Drop obligation in favor of simple Concurrent::IVar based promise class.
  Notable changes:
    - Returned object us of type `Restify::Promise` now.
    - `value` will not raise exception but return `nil` in case of failure. Use `value!` for old behavior.
* Use typhoeus as default adapter
* `Restify.new` returns relation now instead of resource
