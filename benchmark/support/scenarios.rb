# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)

require 'logger'
require 'restify'

require_relative 'server'

module Bench
  # Do not log by default:
  Restify.logger = Logger.new($stderr, level: ENV['LOG_LEVEL']) if ENV['LOG_LEVEL']

  ADAPTERS = {
    'ethon' => -> { Restify::Adapter::Ethon.new },
    'typhoeus' => -> { Restify::Adapter::Typhoeus.new },
    'typhoeus-sync' => -> { Restify::Adapter::Typhoeus.new(sync: true) },
  }.freeze

  # Worker threads kept alive between runs, like an application server
  # would, so that scenarios do not measure creating threads.
  class Pool
    def initialize(size)
      @size = size
      @jobs = Queue.new
      @threads = Array.new(size) do |i|
        Thread.new do
          Thread.current.name = "bench-worker-#{i}"
          loop { work(*@jobs.pop) }
        end
      end
    end

    def run(&block)
      done = Queue.new
      @size.times { @jobs << [block, done] }

      errors = Array.new(@size) { done.pop }.compact
      raise errors.first if errors.any?
    end

    private

    def work(block, done)
      block.call
      done << nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      done << e
    end
  end

  POOL = Pool.new(4)

  RELATIONS = %i[items owner].freeze
  SCENARIOS = {
    'single request' => lambda {|root|
      root.get.value!
    },
    '10 sequential requests' => lambda {|root|
      10.times { root.get.value! }
    },
    '10 parallel requests' => lambda do |root|
      Restify::Promise.new(Array.new(10) { root.get }).value!
    end,
    '4 threads, 10 parallel requests each' => lambda do |root|
      POOL.run { Restify::Promise.new(Array.new(10) { root.get }).value! }
    end,
    '2 parallel requests, 2 relations each' => lambda do |root|
      chains = Array.new(2) do
        root.get.then do |resource|
          Restify::Promise.new(
            RELATIONS.map {|name| resource.rel(name).get },
          )
        end
      end

      Restify::Promise.new(chains).value!
    end,
  }.freeze

  class << self
    def run
      server = Server.new
      uri = server.start!

      puts "Ruby:     #{RUBY_DESCRIPTION}"
      puts "Restify:  #{Restify::VERSION}"
      puts "Server:   #{uri}"
      puts "\nWarmup:\n"

      clients = build_clients(uri)
      warmup!(clients)

      SCENARIOS.each do |name, scenario|
        yield(name, scenario, clients)
      end
    ensure
      server&.stop!
    end

    private

    # Adapters keep connections alive and run their own background
    # thread, therefore each one is instantiated once and reused for all
    # scenarios like an application would (should).
    def build_clients(uri)
      names = ENV.fetch('ADAPTERS', ADAPTERS.keys.join(',')).split(',').map(&:strip)
      names.to_h do |name|
        factory = ADAPTERS.fetch(name) do
          abort "Unknown adapter: #{name} (known: #{ADAPTERS.keys.join(', ')})"
        end

        [name, Restify.new(uri, adapter: factory.call)]
      end
    end

    def warmup!(clients)
      clients.each do |name, root|
        resource = root.get.value!

        unless resource['name'] == 'restify' && RELATIONS.all? {|rel| resource.rel?(rel) }
          abort "Adapter #{name} returned an unexpected resource: #{resource.inspect}"
        end

        10.times { root.get.value! }
        SCENARIOS.each_value {|scenario| scenario.call(root) }

        puts "  #{name}: ok"
      end
    end
  end
end
