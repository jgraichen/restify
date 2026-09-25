# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon do
  describe 'completed transfers' do
    subject(:value) do
      Restify::Promise.create do |writer|
        described_class.new.send(
          :complete,
          easy,
          request,
          writer,
        )
      end.value!
    end

    let(:request) { Restify::Request.new(uri: 'http://example.org/base') }
    let(:return_code) { :ok }
    let(:response_code) { 200 }
    let(:effective_url) { 'http://example.org/base' }

    # A transfer is handed back from libcurl with its return code and,
    # for HTTP, the status code of the response.
    def easy
      instance_double(
        described_class::Easy,
        return_code:,
        response_code:,
        effective_url:,
        response_headers: "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n",
        response_body: '{}',
      )
    end

    it 'fulfills the promise with the response' do
      expect(value.code).to eq 200
      expect(value.uri.to_s).to eq 'http://example.org/base'
    end

    it 'reuses the request URI without redirects' do
      expect(value.uri).to be request.uri
    end

    context 'when redirected' do
      let(:effective_url) { 'http://example.org/other/base' }

      it 'uses the effective URL as the response URI' do
        expect(value.uri.to_s).to eq 'http://example.org/other/base'
      end
    end

    context 'when the transfer failed' do
      let(:return_code) { :couldnt_connect }
      let(:response_code) { 0 }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /connect/i
      end
    end

    # Non-HTTP protocols are refused before a transfer is started, but
    # libcurl still reports success with a zero status code whenever no
    # HTTP status was received, and no status code at all when it cannot
    # be read back. Neither has a response to process.
    context 'without an HTTP status' do
      let(:response_code) { 0 }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /without HTTP status/
      end
    end

    context 'with an unavailable HTTP status' do
      let(:response_code) { nil }

      it 'rejects the promise' do
        expect { value }.to raise_error Restify::NetworkError, /without HTTP status/
      end
    end

    # Unexpected errors must reject the promise too, as the caller would
    # otherwise keep waiting for it until it times out.
    context 'when building the response fails' do
      def easy
        super.tap do |double|
          allow(double).to receive(:response_headers).and_raise('kaboom')
        end
      end

      it 'rejects the promise' do
        expect { value }.to raise_error 'kaboom'
      end
    end
  end

  describe 'waiting on requests' do
    let(:adapter) { described_class.new }

    # Threads that completed a transfer, i.e. ran the event loop.
    let(:completed_by) { Queue.new }

    before do
      stub_request(:get, 'http://stubserver/fast')
        .to_return(status: 200, body: '{}')
      stub_request(:get, 'http://stubserver/slow')
        .to_return { sleep 0.5 and {status: 200, body: '{}'} }

      allow(adapter).to receive(:complete).and_wrap_original do |m, *args|
        completed_by << Thread.current
        m.call(*args)
      end
    end

    def request(path)
      Restify::Request.new(uri: "http://localhost:9292/#{path}")
    end

    def completed_by_threads
      Array.new(completed_by.size) { completed_by.pop }
    end

    it 'runs the event loop in the waiting thread' do
      expect(adapter.call(request('fast')).value!.code).to eq 200
      expect(completed_by_threads).to eq [Thread.current]
    end

    it 'completes requests nobody waits on in the background' do
      adapter.call(request('fast'))

      # Poll without waiting on the promise:
      Timeout.timeout(1) { sleep 0.01 while completed_by.empty? }

      expect(completed_by_threads).not_to include Thread.current
    end

    it 'times out without blocking other requests' do
      expect { adapter.call(request('slow')).value!(0.1) }.to raise_error Timeout::Error
      expect(adapter.call(request('fast')).value!.code).to eq 200
    end

    it 'processes requests from many threads' do
      threads = Array.new(8) do
        Thread.new do
          Array.new(5) { adapter.call(request('fast')).value!.code }
        end
      end

      expect(threads.flat_map(&:value)).to all eq 200
    end

    # Only the adapter's own promises are completed by whichever thread
    # runs the event loop. Callbacks chained to them must still run in
    # the thread waiting on them, and only when waiting on them.
    describe 'chained callbacks' do
      it 'does not run them before waiting on them' do
        ran_in = Queue.new
        promise = adapter.call(request('fast'))
        chained = promise.then { ran_in << Thread.current }

        promise.value!
        expect(ran_in).to be_empty

        chained.value!
        expect(ran_in.pop(timeout: 1)).to eq Thread.current
      end

      it 'runs them in the waiting thread when another thread runs the loop' do
        # Keep the loop busy in another thread, until after the fast
        # request completed.
        driver = Thread.new { adapter.call(request('slow')).value! }
        sleep 0.1

        chained = adapter.call(request('fast')).then do |response|
          [Thread.current, response.code]
        end

        expect(chained.value!).to eq [Thread.current, 200]
        expect(completed_by_threads.first).to eq driver
      ensure
        driver&.join
      end
    end

    context 'when waiting from within the event loop' do
      it 'does not run the loop again' do
        adapter.instance_variable_get(:@loop).acquire(0.1)

        expect(adapter.drive(Restify::Promise.new, Restify::Timeout.new(0.1))).to be false
      end
    end
  end

  describe 'after fork' do
    let(:adapter) { described_class.new }
    let(:connects) { Queue.new }

    before do
      stub_request(:get, 'http://stubserver/fast')
        .to_return(status: 200, body: '{}')
      stub_request(:get, 'http://stubserver/slow')
        .to_return { sleep 0.5 and {status: 200, body: '{}'} }

      allow(adapter).to receive(:complete).and_wrap_original do |m, easy, *args|
        connects << Ethon::Curl.get_info_long(:num_connects, easy.handle)
        m.call(easy, *args)
      end
    end

    def request(path)
      Restify::Request.new(uri: "http://localhost:9292/#{path}")
    end

    def in_child
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        result = begin
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          e
        end
        writer.write(Marshal.dump(result))
      ensure
        # Skip at exit handlers of the parent
        exit!(0)
      end

      writer.close
      Marshal.load(reader.read) # rubocop:disable Security/MarshalLoad
    ensure
      reader&.close
      Process.wait(pid) if pid
    end

    it 'does not use connections of the parent process' do
      # The parent process pools and reuses its connection.
      2.times { adapter.call(request('fast')).value! }
      expect(Array.new(2) { connects.pop(timeout: 1) }).to eq [1, 0]

      result = in_child do
        code = adapter.call(request('fast')).value!.code
        [code, connects.pop(timeout: 1)]
      end

      # A new connection, not the one pooled by the parent process
      expect(result).to eq [200, 1]

      # The parent process can still use its connections
      expect(adapter.call(request('fast')).value!.code).to eq 200
    end

    it 'rejects requests started before the fork in the child process' do
      promise = adapter.call(request('slow'))

      result = in_child do
        promise.value!
      rescue Restify::NetworkError => e
        e.message
      end

      expect(result).to include 'before fork'
      expect(promise.value!.code).to eq 200
    end
  end
end
