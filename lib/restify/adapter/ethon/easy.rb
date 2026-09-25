# frozen_string_literal: true

module Restify
  module Adapter
    class Ethon < Base
      #
      # A libcurl easy handle for Restify requests, translating a
      # request into libcurl options, and a completed transfer back into
      # a response.
      #
      # Handles are reused for many requests, see `Pool`.
      #
      # @api private
      #
      class Easy < ::Ethon::Easy
        attr_accessor :_otel_span, :_restify_request, :_restify_writer

        TIMEOUT_MS = Options.number(:timeout_ms)
        CONNECTTIMEOUT_MS = Options.number(:connecttimeout_ms)

        def reset
          @_otel_span = @_restify_request = @_restify_writer = nil

          super
        end

        def prepare(request, options)
          options.apply(self)

          self.url = request.uri.to_s
          self.headers = DEFAULT_HEADERS.merge(request.headers)

          if request.timeout
            # libcurl requires millisecond-based timeouts so fractional
            # seconds must be converted and rounded.
            timeout = (request.timeout * 1000).ceil
            ::Ethon::Curl.easy_setopt(handle, TIMEOUT_MS, :long, timeout)
            ::Ethon::Curl.easy_setopt(handle, CONNECTTIMEOUT_MS, :long, timeout)
          end

          prepare_method(request.method, request.body)

          # The OpenTelemetry instrumentation for Ethon takes the method
          # from `#http_request`, which is not used here.
          @otel_method = request.method
        end

        def response(request)
          code = return_code
          if code != :ok
            raise Restify::NetworkError.new(request, ::Ethon::Curl.easy_strerror(code))
          end

          # Non-HTTP protocols are refused before a transfer is started,
          # but libcurl still reports success with a zero status code
          # whenever no HTTP status was received, and no status code at
          # all when it cannot be read back.
          status = response_code
          if status.nil? || status.zero?
            raise Restify::NetworkError.new(request, 'Response without HTTP status')
          end

          ::Restify::Response.new(
            request,
            effective_uri(request),
            status,
            parse_headers(response_headers),
            response_body,
          )
        end

        private

        # Like Ethon's actions for each method, see `Ethon::Easy::Http`.
        # An empty body counts as no body.
        def prepare_method(method, body)
          body = nil if body.nil? || body.empty?

          case method
            when 'get'
              if body
                postfields(body)
                self.customrequest = 'GET'
              end
            when 'post'
              postfields(body || '')
            when 'put'
              self.upload = true
              self.infilesize = body ? body.bytesize : 0
              set_read_callback(body) if body
            when 'head'
              postfields(body) if body
              self.nobody = true
            else
              postfields(body) if body
              self.customrequest = method.upcase
          end
        end

        def postfields(body)
          self.postfieldsize = body.bytesize
          self.copypostfields = body
        end

        def effective_uri(request)
          url = effective_url

          # Only parse the URL after redirects, as parsing is expensive.
          return request.uri if url.nil? || url == request.uri.to_s

          Addressable::URI.parse(url)
        end

        def parse_headers(raw)
          headers = {}
          return headers if raw.nil?

          # The raw headers can contain multiple blocks, e.g. from
          # informational responses or when following redirects; only
          # use the latest ones:
          block = raw.split(/\r?\n\r?\n/).reject {|b| b.strip.empty? }.last

          # Split on newlines that are not followed by whitespace to
          # keep folded header values together.
          block.to_s.split(/\r?\n(?!\s)/).each do |line|
            line = line.strip
            next if line.empty? || line.start_with?('HTTP/')

            key, value = line.split(':', 2)
            next if value.nil?

            key = key.strip.upcase.tr('-', '_')
            value = value.strip.gsub(/\r?\n\s*/, ' ')

            case (current = headers[key])
              when nil then headers[key] = value
              when Array then current << value
              else headers[key] = [current, value]
            end
          end

          headers
        end
      end
    end
  end
end
