# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

---

### New

- Support for Ruby 3.4

### Changes

### Fixes

### Breaks

- Remove indifferent access methods (Hashie) from responses
- Removed `em` and `em-pooled` adapters
- Require Ruby 3.1+

## 1.15.2 - (2021-12-23)

---

### Fixes

- ActiveSupport v7.0 issues with cache module

## 1.15.1 - (2021-07-15)

---

### Fixes

- Typhoeus internal exception when request timed out

## 1.15.0 - (2021-07-09)

---

### New

- Improve memory usage when running lots of requests with typhoeus adapter
- Use hydra for synchronous requests
- Increased thread stability of typhoeus adapter (new internal queuing mechanism)

### Changes

- Use Ruby 2.5 as baseline for testing and linting
- Add Ruby 3.0 to automated testing
- Changed timing behavior for multiple requests due to new internal queuing mechanism for the typhoeus adapter

## 1.14.0 - (2020-12-15)

---

### New

- Allow making requests with non-JSON bodies and custom content types (#42)

## 1.13.0 - (2020-06-12)

---

### New

- typhoeus: Support setting per-request libcurl options on adapter
- typhoeus: Enable short TCP keepalive probes by default (5s/5s)

## 1.12.0 - (2020-04-01)

---

### Added

- Explicit exception class for HTTP status code 410 (Gone)

### Changed

### Fixed

- `GatewayError` exception classes introduced in v1.11.0 now properly inherit from `ServerError` (#30)

## 1.11.0 - (2019-07-11)

### Added

- Explicit exception classes for HTTP status codes 500, 502, 503, 504

## 1.10.0 - 2018-12-11

### Changed

- Raise more specific error on a few status codes (#17)
- Complete promises with an empty list (but a list) of dependencies (#18)

## 1.9.0 - 2018-11-13

### Changed

- Do not raise error on 3XX responses but return responses

## 1.8.0 - 2018-08-22

### Added

- Add HEAD request method (#16)

## 1.7.0 - 2018-08-15

### Added

- Introduce promise dependency timeouts (#15)

## 1.6.0 - 2018-08-09

### Changed

- Specify headers on restify clients and individual requests (#14)

## 1.5.0 - 2018-07-31

### Added

- Add MessagePack processor enabled by default

### Changed

- Tune typhoeus adapter to be more race-condition resilent

## 1.4.4 - 2018-07-13

### Added

- Add `#request` to `NetworkError` to ease debugging

### Changed

- Fix race condition in typhoeus adapter

## 1.4.3 - 2017-11-15

### Added

- Add advanced logging capabilities using logging gem

### Changed

- Improve compatibility with webmocks returning `nil` as headers

## 1.4.1 - 2017-11-15

### Changed

- Fix possible deadlock issues

## 1.4.0 - 2017-11-10

### Added

- Add timeout option to requests (only supported by typhoeus adapter)

### Changed

- Fix possible concurrency issue with typhoeus adapter

## 1.3.1 - 2017-11-10

### Changed

- Improve typhoeus adapters initial request queuing
- Disable default pipelining

## 1.3.0 - 2017-11-08

### Changed

- Improve typhoeus adapter to better utilize concurrency
- Default to new typhoeus adapter

## 1.2.1 - 2017-10-30

### Changed

- Fix issue with Ruby 2.2 compatibility

## 1.2.0 - 2017-10-30

### Added

- Add experimental PooledEM adapter (#10)

### Changed

- Improve marshaling of resources

## 1.1.0 - 2017-05-12

### Added

- Add shortcuts for creating fulfilled / rejected promises (#6)

### Changed

- Return response body if no processor matches (#7)

## 1.0.0 - 2016-08-22

### Added

- Experimental cache API doing nothing for now

### Changed

- Use `~> 1.0` of `concurrent-ruby`

## 0.5.0 - 2016-04-04

### Added

- Add `sync` option to typhoeus adapter
- Add registry for storing entry points

### Changed

- Make eventmachine based adapter default

## 0.4.0 - 2016-02-24

### Added

- Add method to explicit access resource data

### Changed

- Use typhoeus as default adapter
- `Restify.new` returns relation now instead of resource

### Removed

- Drop obligation in favor of simple Concurrent::IVar based promise class.
  Notable changes:
  - Returned object us of type `Restify::Promise` now.
  - `value` will not raise exception but return `nil` in case of failure. Use `value!` for old behavior.
