# frozen_string_literal: true

require 'restify'
require 'webmock'

module WebMock
  module HttpLibAdapters
    #
    # WebMock support for Restify (independent of the adapter)
    #
    # Requests are intercepted before they are handed over to an
    # adapter. Stubbed responses are returned as they are, including
    # redirects, like WebMock does for other libcurl-based libraries.
    # Requests not stubbed are passed on to the adapter, if allowed.
    #
    # Must be loaded before WebMock is enabled, e.g. in
    # `spec_helper.rb`:
    #
    #     require 'webmock/rspec'
    #     require 'restify/webmock'
    #
    class RestifyAdapter < HttpLibAdapter
      adapter_for :restify

      class << self
        def enable!
          @enabled = true
        end

        def disable!
          @enabled = false
        end

        def enabled?
          @enabled == true
        end

        # Respond to a request with a stubbed response, or pass it on to
        # the given block if allowed.
        #
        # @api private
        def call(request, &)
          signature = signature(request)
          RequestRegistry.instance.requested_signatures.put(signature)

          stub = StubRegistry.instance.response_for_request(signature)
          return passthrough(signature, &) unless stub

          CallbackRegistry.invoke_callbacks({lib: :restify}, signature, stub)

          Restify::Promise.fulfilled(respond(request, stub))
        rescue Exception => e # rubocop:disable Lint/RescueException
          # e.g. `NetConnectNotAllowedError`
          Restify::Promise.rejected(e)
        end

        private

        def signature(request)
          RequestSignature.new(
            request.method.to_sym,
            request.uri.to_s,
            body: request.body,
            headers: request.headers,
          )
        end

        def passthrough(signature)
          unless ::WebMock.net_connect_allowed?(signature.uri)
            raise NetConnectNotAllowedError.new(signature)
          end

          yield.tap do |promise|
            # Observers run when the request is complete, even when
            # nobody waits on the promise.
            promise.add_observer do |_, response, _|
              next unless response

              CallbackRegistry.invoke_callbacks(
                {lib: :restify, real_request: true},
                signature,
                webmock_response(response),
              )
            end
          end
        end

        def respond(request, stub)
          raise Restify::NetworkError.new(request, 'Timeout was reached') if stub.should_timeout

          stub.raise_error_if_any

          headers = (stub.headers || {}).to_h do |name, value|
            [name.upcase.tr('-', '_'), value]
          end

          Restify::Response.new(request, request.uri, stub.status[0], headers, stub.body)
        end

        def webmock_response(response)
          Response.new.tap do |webmock|
            webmock.status = [response.code, response.message.to_s]
            webmock.headers = response.headers.to_h do |name, value|
              [name.split('_').map(&:capitalize).join('-'), value]
            end
            webmock.body = response.body.to_s
          end
        end
      end

      # Intercept requests after `Adapter::Telemetry` but before
      # `Adapter::Base#call` so that telemetry is included.
      #
      # @api private
      module Intercept
        def call(request)
          return super unless RestifyAdapter.enabled?

          RestifyAdapter.call(request) { super }
        end
      end

      ::Restify::Adapter::Telemetry.include(Intercept)
    end
  end
end
