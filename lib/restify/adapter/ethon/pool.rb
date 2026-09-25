# frozen_string_literal: true

module Restify
  module Adapter
    class Ethon < Base
      #
      # Idle libcurl easy handles, kept for reuse.
      #
      # Handles can be taken from any thread. Handles of completed
      # transfers only become available again with `#release_completed`,
      # as libcurl and Ethon may still use a handle after its completion
      # callback. Therefore, `#complete` and `#release_completed` must
      # only be called by the thread running the event loop, and the
      # latter only after libcurl returned.
      #
      # @api private
      #
      class Pool
        def initialize(size:, &factory)
          @size    = size
          @factory = factory
          @mutex   = Mutex.new

          @idle      = []
          @completed = []
        end

        def checkout
          @mutex.synchronize { @idle.pop } || @factory.call
        end

        def complete(easy)
          @completed << easy
        end

        def release_completed
          until @completed.empty?
            easy = @completed.pop
            easy.reset

            @mutex.synchronize { @idle << easy if @idle.size < @size }
          end
        end

        # Forget all handles without releasing them as they belong to
        # the parent process.
        def forked!
          @mutex.synchronize do
            [*@idle, *@completed].each {|easy| easy.handle.autorelease = false }

            @idle.clear
            @completed.clear
          end
        end
      end
    end
  end
end
