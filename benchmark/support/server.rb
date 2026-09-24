# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'socket'
require 'tmpdir'

module Bench
  # A minimal local caddy HTTP server serving a static hypermedia JSON
  # document. The binary must be on the path, or be given via the
  # `CADDY` environment variable.
  #
  class Server
    PAYLOAD = {
      'id' => 42,
      'name' => 'restify',
      'description' => 'An experimental hypermedia REST client.',
      'created_at' => '2014-02-25T12:00:00Z',
      'tags' => %w[http rest hypermedia parallel],
      'self_url' => '/resources/42',
      'items_url' => '/resources/42/items{?page,per_page}',
      'owner_url' => '/users/jgraichen',
      'items' => Array.new(10) do |i|
        {
          'id' => i,
          'title' => "Item #{i}",
          'self_url' => "/resources/42/items/#{i}",
        }
      end,
    }.freeze

    BODY = JSON.generate(PAYLOAD).freeze
    HOST = ENV.fetch('HOST', 'localhost')
    CADDY = ENV.fetch('CADDY', 'caddy')

    attr_reader :uri

    def initialize(host: HOST, caddy: CADDY)
      @host = host
      @caddy = caddy
    end

    def start!
      return @uri if @uri

      @dir = Dir.mktmpdir('restify-bench')

      config = File.join(@dir, 'caddy.json')
      File.write(config, JSON.generate(caddy_config))

      @log = File.join(@dir, 'caddy.log')
      @pid = Process.spawn(
        @caddy, 'run', '--config', config,
        in: File::NULL,
        out: @log,
        err: @log,
      )

      at_exit { stop! }

      port = await

      @uri = "http://#{@host}:#{port}/"
    rescue Errno::ENOENT
      abort "Caddy not found: install it or set CADDY to the binary (tried #{@caddy.inspect})"
    end

    def stop!
      if @pid
        Process.kill('TERM', @pid)
        Process.wait(@pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      # Already gone
    ensure
      FileUtils.remove_entry(@dir) if @dir
      @pid = @dir = @log = @uri = nil
    end

    private

    def caddy_config
      {
        admin: {
          disabled: true,
          config: {
            persist: false,
          },
        },
        storage: {
          module: 'file_system',
          root: File.join(@dir, 'data'),
        },
        logging: {
          logs: {default: {level: 'INFO'}},
        },
        apps: {
          http: {
            servers: {
              bench: {
                listen: ["#{@host}:0"],
                protocols: %w[h1],
                automatic_https: {disable: true},
                routes: [{
                  handle: [{
                    handler: 'static_response',
                    status_code: 200,
                    headers: {'Content-Type' => ['application/json']},
                    body: BODY,
                  }],
                }],
              },
            },
          },
        },
      }
    end

    # Wait until Caddy reports its port and the server answers
    def await(timeout: 10)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      port = nil

      loop do
        port ||= listen_port
        return port if port && probe(port)

        if Process.wait(@pid, Process::WNOHANG)
          @pid = nil
          raise "Caddy exited during startup:\n#{File.read(@log)}"
        end

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise "HTTP server did not come up within #{timeout}s:\n#{File.read(@log)}"
        end

        Kernel.sleep(0.05)
      end
    end

    # Find the port in caddy's log
    def listen_port
      File.foreach(@log) do |line|
        next unless line.include?('"port 0 listener"')

        port = line[/"actual_address":"[^"]*:(\d+)"/, 1]
        return Integer(port) if port
      end

      nil
    end

    def probe(port)
      socket = Socket.tcp(@host, port, connect_timeout: 1)
      socket.write("GET / HTTP/1.0\r\nHost: #{@host}\r\n\r\n")
      socket.read(12).to_s.include?('200')
    rescue SystemCallError, IOError
      false
    ensure
      socket&.close
    end
  end
end
