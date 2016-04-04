require 'typhoeus'

module Restify
  #
  module Adapter
    #
    class Typhoeus

      def initialize(**options)
        @queue   = Queue.new
        @hydra   = ::Typhoeus::Hydra.new
        @options = options

        Thread.new do
          begin
            loop do
              while (req = convert(*@queue.pop))
                @hydra.queue req

                if @queue.size == 0
                  @hydra.run
                end
              end
            end
          rescue Exception => e
            puts "#{self.class}: #{e.message}"
          end
        end
      end

      def sync?
        @options.fetch :sync, false
      end

      def queue(request, writer)
        if sync?
          @hydra.queue convert request, writer
          @hydra.run
        else
          @queue.push [request, writer]
        end
      end

      def call(request)
        Promise.create do |writer|
          queue request, writer
        end
      end

      private

      def convert(request, writer)
        req = ::Typhoeus::Request.new \
          request.uri,
          method: request.method,
          headers: request.headers,
          body: request.body

        req.on_complete do |response|
          uri    = request.uri
          status = response.code
          body   = response.body

          headers = response.headers.each_with_object({}) do |header, hash|
            hash[header[0].upcase.tr('-', '_')] = header[1]
          end

          writer.fulfill Response.new request, uri, status, headers, body

          while @queue.size > 0
            @hydra.queue convert(*@queue.pop(true))
          end
        end

        req
      end
    end
  end
end
