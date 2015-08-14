require 'celluloid/io'
require 'http'

module Restify
  #
  module Adapter
    #
    class Celluloid
      include ::Celluloid::IO

      def process(request, writer)
        response = ::HTTP
          .headers(request.headers)
          .send request.method.downcase,
            request.uri.to_s,
            body: request.body,
            socket_class: ::Celluloid::IO::TCPSocket

        uri     = response.uri
        status  = response.status.code
        body    = response.body.to_s
        headers = response.headers.to_h.each_with_object({}) do |header, hash|
          hash[header[0].upcase.tr('-', '_')] = header[1]
        end

        writer.fulfill Response.new request, uri, status, headers, body
      end

      def call(request)
        Obligation.create do |writer|
          async.process request, writer
        end
      end
    end
  end
end
