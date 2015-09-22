## master

* Drop obligation in favor of simple Concurrent::IVar based promise class.
  Notable changes:
    - Returned object us of type `Restify::Promise` now.
    - `value` will not raise exception but return `nil` in case of failure. Use `value!` for old behavior.
