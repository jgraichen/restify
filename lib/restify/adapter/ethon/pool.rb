# frozen_string_literal: true

module Restify
  module Adapter
    class Ethon < Base
      #
      # Idle libcurl easy handles, kept for reuse.
      #
      # Handles can be taken and released from any thread. A handle must
      # only be released once libcurl is done with it.
      #
      # @api private
      #
      class Pool
        def initialize(size:, &factory)
          @size    = size
          @factory = factory
          @mutex   = Mutex.new
          @idle    = []
        end

        def checkout
          @mutex.synchronize { @idle.pop } || @factory.call
        end

        def release(easy)
          easy.reset

          @mutex.synchronize { @idle << easy if @idle.size < @size }
        end

        # Forget all handles without releasing them as they belong to
        # the parent process.
        def forked!
          @mutex.synchronize do
            @idle.each {|easy| easy.handle.autorelease = false }
            @idle.clear
          end
        end
      end
    end
  end
end
