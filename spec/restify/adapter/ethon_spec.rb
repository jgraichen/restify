# frozen_string_literal: true

require 'spec_helper'

describe Restify::Adapter::Ethon do
  describe 'completed transfers' do
    subject(:value) do
      Restify::Promise.create do |writer|
        described_class.new.send(:complete, easy, request, writer)
      end.value!
    end

    let(:request) { Restify::Request.new(uri: 'http://example.org/base') }
    let(:easy) { instance_double(described_class::Easy, return_code: :ok, response_code: 200) }

    it 'fulfills the promise with the response' do
      response = instance_double(Restify::Response)
      allow(easy).to receive(:response).with(request).and_return(response)

      expect(value).to be response
    end

    it 'rejects the promise on network errors' do
      allow(easy).to receive(:response).and_raise(Restify::NetworkError.new(request, 'kaboom'))

      expect { value }.to raise_error Restify::NetworkError, /kaboom/
    end

    # Unexpected errors must reject the promise too, as the caller would
    # otherwise keep waiting for it until it times out.
    it 'rejects the promise on unexpected errors' do
      allow(easy).to receive(:response).and_raise('kaboom')

      expect { value }.to raise_error 'kaboom'
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
        adapter.instance_variable_get(:@events).instance_variable_get(:@lock).acquire(0.1)

        expect(adapter.drive(Restify::Promise.new, Restify::Timeout.new(0.1))).to be false
      end
    end
  end

  describe 'reusing easy handles' do
    let(:adapter) { described_class.new }
    let(:root) { Restify.new('http://localhost:9292/echo', adapter:) }

    # Easy handles of completed transfers, in order.
    let(:handles) { [] }

    before do
      allow(adapter).to receive(:complete).and_wrap_original do |m, easy, *args|
        handles << easy
        m.call(easy, *args)
      end
    end

    def echo(method, *, **)
      JSON.parse(root.send(method, *, **).value!.response.body)
    end

    it 'reuses the handle of a completed request' do
      2.times { root.get.value! }

      expect(handles[1]).to be handles[0]
    end

    it 'does not reuse handles of requests in progress' do
      Restify::Promise.new(Array.new(2) { root.get }).value!

      expect(handles[1]).not_to be handles[0]
    end

    # Nothing must leak from one request into the next one.
    describe 'subsequent requests' do
      it 'use the method of each request' do
        %i[post get head put patch delete get].each do |method|
          response = root.send(method).value!.response
          next if method == :head

          expect(JSON.parse(response.body)).to include('REQUEST_METHOD' => method.to_s.upcase)
        end
      end

      it 'do not send a previous body' do
        root.post('payload').value!

        expect(echo(:get)).not_to have_key('CONTENT_LENGTH')
      end

      it 'do not send previous headers' do
        root.get(headers: {'X-Custom' => 'yes'}).value!

        expect(echo(:get)).not_to have_key('HTTP_X_CUSTOM')
      end

      it 'receive a body after a HEAD request' do
        root.head.value!

        expect(root.get.value!.response.body).not_to be_empty
      end
    end

    describe 'request bodies' do
      before { stub_request(:any, 'http://stubserver/body') }

      let(:root) { Restify.new('http://localhost:9292/body', adapter:) }

      %i[post put patch].each do |method|
        it "sends #{method.upcase} bodies" do
          root.send(method, 'payload').value!
          root.send(method, 'other').value!

          expect(a_request(method, 'http://stubserver/body').with(body: 'payload')).to have_been_made.once
          expect(a_request(method, 'http://stubserver/body').with(body: 'other')).to have_been_made.once
        end
      end
    end
  end

  describe 'options' do
    it 'raises on unknown options' do
      expect { described_class.new(options: {unknown: 1}) }.to raise_error ArgumentError, /Unknown libcurl option/
    end

    it 'sets options on each request' do
      adapter = described_class.new(options: {useragent: 'restify-spec'})
      root = Restify.new('http://localhost:9292/echo', adapter:)

      2.times do
        expect(JSON.parse(root.get.value!.response.body)).to include('HTTP_USER_AGENT' => 'restify-spec')
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
