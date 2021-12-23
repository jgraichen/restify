# frozen_string_literal: true

require 'puma'
require 'rack'
require 'webmock'
require 'webmock/rspec/matchers'

module Stub
  # This Rack application matches the request received from rack against the
  # webmock stub database and returns the response.
  #
  # A custom server name is used to
  #   1) has a stable name without a dynamic port for easier `#stub_request`
  #      calls, and
  #   2) to ensure no actual request is intercepted (they are send to
  #      `localhost:<port>`).
  #
  # If no stub is found a special HTTP 599 error code will be returned.
  class Handler
    def call(env)
      signature = WebMock::RequestSignature.new(
        env['REQUEST_METHOD'].downcase,
        "http://stubserver#{env['REQUEST_URI']}",
      )

      # Extract request headers from rack env. Most header should start with
      # `HTTP_` but at least content type is present as `CONTENT_TYPE`.
      headers = {}
      env.each_pair do |key, value|
        case key
          when /^HTTP_(.*)$/, /^(CONTENT_.*)$/
            headers[Regexp.last_match(1)] = value
        end
      end

      # Read request body from socket into string
      signature.body = env['rack.input'].read
      signature.headers = headers

      WebMock::RequestRegistry.instance.requested_signatures.put(signature)
      response = ::WebMock::StubRegistry.instance.response_for_request(signature)

      # Return special HTTP 599 with the error message that would normally
      # appear on missing stubs.
      unless response
        return [599, {}, [WebMock::NetConnectNotAllowedError.new(signature).message]]
      end

      if response.should_timeout
        sleep 10
        return [599, {}, ['Timeout']]
      end

      status = response.status
      status = status.to_s.split(' ', 2) unless status.is_a?(Array)
      status = Integer(status[0])

      [status, response.headers || {}, [response.body.to_s]]
    end
  end

  class Exception < ::StandardError; end

  # Inject into base adapter to have HTTP 599 (missing stub) error raised as an
  # extra exception, not just a server error.
  module Patch
    def call(request)
      super.then do |response|
        next response unless response.code == 599

        raise ::Stub::Exception.new(response.body)
      end
    end

    ::Restify::Adapter::Base.prepend(self)
  end

  class << self
    def start_server!
      @server = ::Puma::Server.new(Handler.new)
      @server.add_tcp_listener('localhost', 9292)

      Thread.new do
        @server.run
      end
    end
  end
end

RSpec.configure do |config|
  config.include WebMock::API
  config.include WebMock::Matchers

  config.before(:suite) do
    Stub.start_server!

    # Net::HTTP adapter must be enabled, otherwise webmock fails to create mock
    # responses from raw strings.
    WebMock.disable!(except: %i[net_http])
  end

  config.around do |example|
    example.run
    WebMock.reset!
  end
end
