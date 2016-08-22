# Changelog

## Next

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
