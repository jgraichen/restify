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

        writer.fulfill Response.new \
          request,
          response.uri,
          response.status.code,
          response.headers.to_h,
          response.body.to_s
      end

      def call(request)
        Obligation.create do |writer|
          async.process request, writer
        end
      end
    end
  end
end
