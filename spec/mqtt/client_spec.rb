# encoding: BINARY
# frozen_string_literal: true

# Encoding is set to binary, so that the binary packets aren't validated as UTF-8

require 'spec_helper'
require 'mqtt'

describe MQTT::Client do
  before do
    # Reset environment variable
    ENV.delete('MQTT_SERVER')
  end

  let(:client) { MQTT::Client.new(host: 'localhost', client_id: 'myclient') }
  let(:socket) do
    socket = StringIO.new
    if socket.respond_to?(:set_encoding)
      socket.set_encoding('binary')
    else
      socket
    end
  end

  describe 'initializing a client' do
    it 'with no arguments, it should use the defaults' do
      client = MQTT::Client.new
      expect(client.host).to eq(nil)
      expect(client.port).to eq(1883)
      expect(client.version).to eq('3.1.1')
      expect(client.keep_alive).to eq(15)
    end

    it 'with a single string argument, it should use it has the host' do
      client = MQTT::Client.new('otherhost.mqtt.org')
      expect(client.host).to eq('otherhost.mqtt.org')
      expect(client.port).to eq(1883)
      expect(client.keep_alive).to eq(15)
    end

    it 'with two arguments, it should use it as the host and port' do
      client = MQTT::Client.new('otherhost.mqtt.org', 1000)
      expect(client.host).to eq('otherhost.mqtt.org')
      expect(client.port).to eq(1000)
      expect(client.keep_alive).to eq(15)
    end

    it 'with named arguments, it should use those as arguments' do
      client = MQTT::Client.new(host: 'otherhost.mqtt.org', port: 1000)
      expect(client.host).to eq('otherhost.mqtt.org')
      expect(client.port).to eq(1000)
      expect(client.keep_alive).to eq(15)
    end

    it 'with a hash containing just a keep alive setting' do
      client = MQTT::Client.new(host: 'localhost', keep_alive: 60)
      expect(client.host).to eq('localhost')
      expect(client.port).to eq(1883)
      expect(client.keep_alive).to eq(60)
    end

    it 'with a combination of a host name and a hash of settings' do
      client = MQTT::Client.new('localhost', keep_alive: 65)
      expect(client.host).to eq('localhost')
      expect(client.port).to eq(1883)
      expect(client.keep_alive).to eq(65)
    end

    it 'with a combination of a host name, port and a hash of settings' do
      client = MQTT::Client.new('localhost', 1888, keep_alive: 65)
      expect(client.host).to eq('localhost')
      expect(client.port).to eq(1888)
      expect(client.keep_alive).to eq(65)
    end

    it 'with a mqtt:// URI containing just a hostname' do
      client = MQTT::Client.new(URI.parse('mqtt://mqtt.example.com'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
      expect(client.ssl).to be_falsey
    end

    it 'with a mqtts:// URI containing just a hostname' do
      client = MQTT::Client.new(URI.parse('mqtts://mqtt.example.com'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(8883)
      expect(client.ssl).to be_truthy
    end

    it 'with a mqtt:// URI containing a custom port number' do
      client = MQTT::Client.new(URI.parse('mqtt://mqtt.example.com:1234/'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1234)
      expect(client.ssl).to be_falsey
    end

    it 'with a mqtts:// URI containing a custom port number' do
      client = MQTT::Client.new(URI.parse('mqtts://mqtt.example.com:1234/'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1234)
      expect(client.ssl).to be_truthy
    end

    it 'with a URI containing a username and password' do
      client = MQTT::Client.new(URI.parse('mqtt://auser:bpass@mqtt.example.com'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
      expect(client.username).to eq('auser')
      expect(client.password).to eq('bpass')
    end

    it 'with a URI containing an escaped username and password' do
      client = MQTT::Client.new(URI.parse('mqtt://foo%20bar:%40123%2B%25@mqtt.example.com'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
      expect(client.username).to eq('foo bar')
      expect(client.password).to eq('@123+%')
    end

    it 'with a URI containing a double escaped username and password' do
      client = MQTT::Client.new(URI.parse('mqtt://foo%2520bar:123%2525@mqtt.example.com'))
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
      expect(client.username).to eq('foo%20bar')
      expect(client.password).to eq('123%25')
    end

    it 'with a URI as a string' do
      client = MQTT::Client.new('mqtt://mqtt.example.com')
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
    end

    it 'with a URI as a string including port' do
      client = MQTT::Client.new('mqtt://user:pass@m10.cloudmqtt.com:13858', nil)
      expect(client.host).to eq('m10.cloudmqtt.com')
      expect(client.port).to eq(13_858)
    end

    it 'with a URI and a hash of settings' do
      client = MQTT::Client.new('mqtt://mqtt.example.com', keep_alive: 65)
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1883)
      expect(client.keep_alive).to eq(65)
    end

    it 'with no arguments uses the MQTT_SERVER environment variable as connect URI' do
      ENV['MQTT_SERVER'] = 'mqtt://mqtt.example.com:1234'
      client = MQTT::Client.new
      expect(client.host).to eq('mqtt.example.com')
      expect(client.port).to eq(1234)
    end

    it 'with an unsupported URI scheme' do
      expect do
        MQTT::Client.new(URI.parse('http://mqtt.example.com/'))
      end.to raise_error(
        'Only the mqtt:// and mqtts:// schemes are supported'
      )
    end

    it 'with three arguments' do
      expect do
        MQTT::Client.new(1, 2, 3)
      end.to raise_error(ArgumentError)
    end
  end

  describe 'setting a client certificate file path' do
    it 'adds a certificate to the SSL context' do
      expect(client.ssl_context.cert).to be_nil
      client.cert_file = fixture_path('client.pem')
      expect(client.ssl_context.cert).to be_a(OpenSSL::X509::Certificate)
    end
  end

  describe 'setting a client certificate directly' do
    it 'adds a certificate to the SSL context' do
      expect(client.ssl_context.cert).to be_nil
      client.cert = File.read(fixture_path('client.pem'))
      expect(client.ssl_context.cert).to be_a(OpenSSL::X509::Certificate)
    end
  end

  describe 'setting a client private key file path' do
    it 'adds a certificate to the SSL context' do
      expect(client.ssl_context.key).to be_nil
      client.key_file = fixture_path('client.key')
      expect(client.ssl_context.key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe 'setting a client private key directly' do
    it 'adds a certificate to the SSL context' do
      expect(client.ssl_context.key).to be_nil
      client.key = File.read(fixture_path('client.key'))
      expect(client.ssl_context.key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe 'setting an encrypted client private key, w/the correct passphrase' do
    let(:key_pass) { 'mqtt' }

    it 'adds the decrypted certificate to the SSL context' do
      expect(client.ssl_context.key).to be_nil
      client.key_file = [fixture_path('client.pass.key'), key_pass]
      expect(client.ssl_context.key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe 'setting an encrypted client private key, w/an incorrect passphrase' do
    let(:key_pass) { 'ttqm' }

    it 'raises an OpenSSL::PKey::RSAError exception' do
      expect(client.ssl_context.key).to be_nil
      expect { client.key_file = [fixture_path('client.pass.key'), key_pass] }.to(
        raise_error(OpenSSL::PKey::RSAError, /Neither PUB key nor PRIV key/)
      )
    end
  end

  describe 'setting a Certificate Authority file path' do
    it 'adds a CA file path to the SSL context' do
      expect(client.ssl_context.ca_file).to be_nil
      client.ca_file = fixture_path('root-ca.pem')
      expect(client.ssl_context.ca_file).to eq(fixture_path('root-ca.pem'))
    end

    it 'enables peer verification' do
      client.ca_file = fixture_path('root-ca.pem')
      expect(client.ssl_context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end
  end

  describe '#connect' do
    before do
      allow(TCPSocket).to receive(:new).and_return(socket)
      allow(Thread).to receive(:new)
      allow(client).to receive(:receive_connack)
    end

    it 'creates a TCP Socket if not connected' do
      expect(TCPSocket).to receive(:new).once.and_return(socket)
      client.connect
    end

    it 'does not create a new TCP Socket if connected' do
      allow(client).to receive(:connected?).and_return(true)
      expect(TCPSocket).not_to receive(:new)
      client.connect
    end

    it 'starts the reader thread if not connected' do
      expect(Thread).to receive(:new).twice
      client.connect
    end

    context 'protocol version 3.1.0' do
      it 'writes a valid CONNECT packet to the socket if not connected' do
        client.version = '3.1.0'
        client.connect
        expect(socket.string).to eq("\020\026\x00\x06MQIsdp\x03\x02\x00\x0f\x00\x08myclient")
      end
    end

    context 'protocol version 3.1.1' do
      it 'writes a valid CONNECT packet to the socket if not connected' do
        client.version = '3.1.1'
        client.connect
        expect(socket.string).to eq("\020\024\x00\x04MQTT\x04\x02\x00\x0f\x00\x08myclient")
      end
    end

    it 'tries and read an acknowledgement packet to the socket if not connected' do
      expect(client).to receive(:receive_connack).once
      client.connect
    end

    it 'raises an exception if no host is configured' do
      expect do
        client = MQTT::Client.new
        client.connect
      end.to raise_error(
        'No MQTT server host set when attempting to connect'
      )
    end

    context 'if a block is given' do
      it 'disconnects after connecting' do
        expect(client).to receive(:disconnect).once
        client.connect { nil }
      end

      it 'disconnects even if the block raises an exception' do
        expect(client).to receive(:disconnect).once
        begin
          client.connect { raise StandardError }
        rescue
          nil
        end
      end
    end

    it 'does not disconnect after connecting, if no block is given' do
      expect(client).not_to receive(:disconnect)
      client.connect
    end

    it 'includes the username and password for an authenticated connection' do
      client.username = 'username'
      client.password = 'password'
      client.connect
      expect(socket.string).to eq(
        "\x10\x28" \
        "\x00\x04MQTT" \
        "\x04\xC2\x00\x0f" \
        "\x00\x08myclient" \
        "\x00\x08username" \
        "\x00\x08password"
      )
    end

    context 'no client id is given' do
      it 'raises an exception if the clean session flag is false' do
        expect do
          client.client_id = nil
          client.clean_session = false
          client.connect
        end.to raise_error(
          'Must provide a client_id if clean_session is set to false'
        )
      end

      context 'protocol version 3.1.0' do
        it 'generates a client if the clean session flag is true' do
          client.version = '3.1.0'
          client.client_id = nil
          client.clean_session = true
          client.connect
          expect(client.client_id).to match(/^\w+$/)
        end
      end

      context 'protocol version 3.1.1' do
        it 'sends empty client if the clean session flag is true' do
          client.version = '3.1.1'
          client.client_id = nil
          client.clean_session = true
          client.connect
          expect(client.client_id).to be_nil
          expect(socket.string).to eq("\020\014\x00\x04MQTT\x04\x02\x00\x0f\x00\x00")
        end
      end
    end

    context 'and using ssl' do
      let(:ssl_socket) do
        double(
          'SSLSocket',
          :sync_close= => true,
          write: true,
          connect: true,
          closed?: false
        )
      end

      it 'uses ssl if it enabled using the ssl: true parameter' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
        expect(ssl_socket).to receive(:connect)

        client = MQTT::Client.new('mqtt.example.com', ssl: true)
        allow(client).to receive(:receive_connack)
        client.connect
      end

      it 'uses ssl if it enabled using the mqtts:// scheme' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
        expect(ssl_socket).to receive(:connect)

        client = MQTT::Client.new('mqtts://mqtt.example.com')
        allow(client).to receive(:receive_connack)
        client.connect
      end

      it 'uses set the SSL version, if the :ssl parameter is a symbol' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
        expect(ssl_socket).to receive(:connect)

        client = MQTT::Client.new('mqtt.example.com', ssl: :TLSv1)
        expect(client.ssl_context).to receive('ssl_version=').with(:TLSv1)
        allow(client).to receive(:receive_connack)
        client.connect
      end

      it 'uses set hostname on the SSL socket for SNI' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
        expect(ssl_socket).to receive(:hostname=).with('mqtt.example.com')

        client = MQTT::Client.new('mqtts://mqtt.example.com')
        allow(client).to receive(:receive_connack)
        client.connect
      end
    end

    context 'with a last will and testament set' do
      before do
        client.set_will('topic', 'hello', qos: 1)
      end

      it "has set the Will's topic" do
        expect(client.will_topic).to eq('topic')
      end

      it "has set the Will's payload" do
        expect(client.will_payload).to eq('hello')
      end

      it "has set the Will's retain flag to true" do
        expect(client.will_retain).to eq false
      end

      it "has set the Will's retain QoS value to 1" do
        expect(client.will_qos).to eq(1)
      end

      it 'includes the will in the CONNECT message' do
        client.connect
        expect(socket.string).to eq(
          "\x10\x22" \
          "\x00\x04MQTT" \
          "\x04\x0e\x00\x0f" \
          "\x00\x08myclient" \
          "\x00\x05topic\x00\x05hello"
        )
      end
    end
  end

  describe '.connect' do
    it 'creates a new client object' do
      client = double('MQTT::Client')
      allow(client).to receive(:connect)
      expect(MQTT::Client).to receive(:new).once.and_return(client)
      MQTT::Client.connect
    end

    it 'calls connect new client object' do
      client = double('MQTT::Client')
      expect(client).to receive(:connect)
      allow(MQTT::Client).to receive(:new).once.and_return(client)
      MQTT::Client.connect
    end

    it 'returns the new client object' do
      client = double('MQTT::Client')
      allow(client).to receive(:connect)
      allow(MQTT::Client).to receive(:new).once.and_return(client)
      expect(MQTT::Client.connect).to eq(client)
    end
  end

  describe '#receive_connack' do
    before do
      client.instance_variable_set(:@socket, socket)
      allow(IO).to receive(:select).and_return([[socket], [], []])
    end

    it 'does not raise an exception for a successful CONNACK packet' do
      socket.write("\x20\x02\x00\x00")
      socket.rewind
      expect { client.send(:receive_connack) }.not_to raise_error
      expect(socket).not_to be_closed
    end

    it "raises an exception if the packet type isn't CONNACK" do
      socket.write("\xD0\x00")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException)
    end

    it "raises an exception if the CONNACK packet return code is 'unacceptable protocol version'" do
      socket.write("\x20\x02\x00\x01")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException, /unacceptable protocol version/i)
    end

    it "raises an exception if the CONNACK packet return code is 'client identifier rejected'" do
      socket.write("\x20\x02\x00\x02")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException, /client identifier rejected/i)
    end

    it "raises an exception if the CONNACK packet return code is 'server unavailable'" do
      socket.write("\x20\x02\x00\x03")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException, /server unavailable/i)
    end

    it 'raises an exception if the CONNACK packet return code is an unknown' do
      socket.write("\x20\x02\x00\xAA")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException, /connection refused/i)
    end

    it 'closes the socket for an unsuccessful CONNACK packet' do
      socket.write("\x20\x02\x00\x05")
      socket.rewind
      expect { client.send(:receive_connack) }.to raise_error(MQTT::ProtocolException, /not authorised/i)
      expect(socket).to be_closed
    end
  end

  describe '#disconnect' do
    before do
      thread = double('Read Thread', alive?: true, kill: true, join: nil)
      client.instance_variable_set(:@socket, socket)
      client.instance_variable_set(:@read_thread, thread)
      client.instance_variable_set(:@write_thread, thread)
    end

    it 'does not do anything if the socket is already disconnected' do
      allow(client).to receive(:connected?).and_return(false)
      client.disconnect(send_msg: true)
      expect(socket.string).to eq('')
    end

    it 'writes a valid DISCONNECT packet to the socket if connected and the send_msg=true an' do
      allow(client).to receive(:connected?).and_return(true)
      client.disconnect(send_msg: true)
      expect(socket.string).to eq("\xE0\x00")
    end

    it 'does not write anything to the socket if the send_msg=false' do
      allow(client).to receive(:connected?).and_return(true)
      client.disconnect(send_msg: false)
      expect(socket.string).to be_empty
    end

    it 'calls the close method on the socket' do
      allow(client).to receive(:connected?).and_return(true)
      expect(socket).to receive(:close)
      client.disconnect
    end
  end

  describe '#publish' do
    let(:client_class) do
      Class.new(MQTT::Client) do
        def initialize
          super(host: 'localhost')
          @injected_pubacks = {}
        end

        def inject_puback(packet)
          @injected_pubacks[packet.id] = packet
        end

        def register_for_ack(packet)
          if @injected_pubacks.key?(packet.id)
            queue = Queue.new
            queue << @injected_pubacks[packet.id]
            return MQTT::Client::PendingAck.new(packet, queue)
          end

          super
        end
      end
    end

    let(:client) { client_class.new }

    before do
      allow(client).to receive(:connected?).and_return(true)
      allow(client).to receive(:send_packet) do |packet|
        socket.write(packet.to_s)
      end
    end

    it 'respects timeouts' do
      require 'socket'
      rd, _wr = UNIXSocket.pair
      client = MQTT::Client.new(host: 'localhost', ack_timeout: 0.5, resend_limit: 1)
      allow(client).to receive(:connected?).and_return(true)
      client.instance_variable_set(:@socket, rd)
      t = Thread.new do
        loop do
          client.send :receive_packet
        end
      end
      start = client.send(:current_time)
      client.instance_variable_set(:@last_packet_received_at, start)
      client.instance_variable_set(:@last_packet_sent_at, start)
      expect { client.publish('topic', 'payload', qos: 1) }.to raise_error(MQTT::ResendLimitExceededException)
      elapsed = client.send(:current_time) - start
      t.kill
      expect(elapsed).to be_within(0.1).of(0.5)
    end

    it 'resends packets' do
      require 'socket'
      rd, _wr = UNIXSocket.pair
      client = MQTT::Client.new(host: 'localhost', ack_timeout: 0.5, resend_limit: 2)
      allow(client).to receive(:connected?).and_return(true)
      client.instance_variable_set(:@socket, rd)
      received_packets = []
      allow(client).to receive(:send_packet) do |packet|
        received_packets << packet.dup
      end

      t = Thread.new do
        loop do
          client.send :receive_packet
        end
      end
      start = client.send(:current_time)
      client.instance_variable_set(:@last_packet_received_at, start)
      client.instance_variable_set(:@last_packet_sent_at, start)
      expect { client.publish('topic', 'payload', qos: 1) }.to raise_error(MQTT::ResendLimitExceededException)
      elapsed = client.send(:current_time) - start
      t.kill
      expect(elapsed).to be_within(0.1).of(1.0)
      expect(received_packets.length).to eq 2
      expect(received_packets.map(&:id)).to eq [1, 1]
      expect(received_packets[0].duplicate).to eq false
      expect(received_packets[1].duplicate).to eq true
    end

    it 'writes a valid PUBLISH packet to the socket without the retain flag' do
      client.publish('topic', 'payload')
      expect(socket.string).to eq("\x30\x0e\x00\x05topicpayload")
    end

    it 'writes a valid PUBLISH packet to the socket with the retain flag set' do
      client.publish('topic', 'payload', retain: true)
      expect(socket.string).to eq("\x31\x0e\x00\x05topicpayload")
    end

    it 'writes a valid PUBLISH packet to the socket with the QoS set to 1' do
      inject_puback(1)
      client.publish('topic', 'payload', qos: 1)
      expect(socket.string).to eq("\x32\x10\x00\x05topic\x00\x01payload")
    end

    it 'wraps the packet id after 65535' do
      client.instance_variable_set(:@last_packet_id, 0xfffe)
      inject_puback(0xffff)
      client.publish('topic', 'payload', qos: 1)
      expect(client.instance_variable_get(:@last_packet_id)).to eq(0xffff)

      socket.string = +''
      inject_puback(1)
      client.publish('topic', 'payload', qos: 1)
      expect(socket.string).to eq("\x32\x10\x00\x05topic\x00\x01payload")
    end

    it 'writes a valid PUBLISH packet to the socket with the QoS set to 2' do
      inject_puback(1)
      client.publish('topic', 'payload', qos: 2)
      expect(socket.string).to eq("\x34\x10\x00\x05topic\x00\x01payload")
    end

    it 'writes a valid PUBLISH packet with no payload' do
      client.publish('test')
      expect(socket.string).to eq("\x30\x06\x00\x04test")
    end

    it 'raises an ArgumentError exception, if the topic is nil' do
      expect do
        client.publish(nil)
      end.to raise_error(
        ArgumentError,
        'Topic name cannot be nil'
      )
    end

    it 'raises an ArgumentError exception, if the topic is empty' do
      expect do
        client.publish('')
      end.to raise_error(
        ArgumentError,
        'Topic name cannot be empty'
      )
    end

    it 'correctly assigns consecutive ids to packets with QoS 1' do
      inject_puback(1)
      inject_puback(2)

      expect(client).to receive(:send_packet) { |packet| expect(packet.id).to eq(1) }
      client.publish 'topic', 'message', qos: 1
      expect(client).to receive(:send_packet) { |packet| expect(packet.id).to eq(2) }
      client.publish 'topic', 'message', qos: 1
    end
  end

  describe '#subscribe' do
    before do
      allow(client).to receive(:connected?).and_return(true)
      allow(client).to receive(:send_packet) do |packet|
        socket.write(packet.to_s)
      end
    end

    it 'writes a valid SUBSCRIBE packet to the socket if given a single topic String' do
      client.subscribe('a/b')
      expect(socket.string).to eq("\x82\x08\x00\x01\x00\x03a/b\x00")
    end

    it 'writes a valid SUBSCRIBE packet to the socket if given a two topic Strings in an Array' do
      client.subscribe('a/b', 'c/d')
      expect(socket.string).to eq("\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x00")
    end

    it 'writes a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in an Array' do
      client.subscribe(['a/b', 0], ['c/d', 1])
      expect(socket.string).to eq("\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01")
    end

    it 'writes a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in a Hash' do
      client.subscribe({ 'a/b' => 0, 'c/d' => 1 })
      expect(socket.string).to eq("\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01")
    end
  end

  describe '#queue_length' do
    it 'returns 0 if there are no incoming messages waiting' do
      expect(client.queue_length).to eq(0)
    end

    it 'returns 1 if there is one incoming message waiting' do
      inject_packet(topic: 'topic0', payload: 'payload0', qos: 0)
      expect(client.queue_length).to eq(1)
    end

    it 'returns 2 if there are two incoming message waiting' do
      inject_packet(topic: 'topic0', payload: 'payload0', qos: 0)
      inject_packet(topic: 'topic0', payload: 'payload1', qos: 0)
      expect(client.queue_length).to eq(2)
    end
  end

  describe '#queue_empty?' do
    it 'returns return true if there no incoming messages waiting' do
      expect(client).to be_queue_empty
    end

    it 'returns return false if there is an incoming messages waiting' do
      inject_packet(topic: 'topic0', payload: 'payload0', qos: 0)
      expect(client).not_to be_queue_empty
    end
  end

  describe '#clear_queue' do
    it 'clears the waiting incoming messages' do
      inject_packet(topic: 'topic0', payload: 'payload0', qos: 0)
      expect(client.queue_length).to eq(1)
      client.clear_queue
      expect(client.queue_length).to eq(0)
    end
  end

  describe '#get' do
    before do
      client.instance_variable_set(:@socket, socket)
      allow(client).to receive(:connected?).and_return(true)
    end

    it 'successfullies receive a valid PUBLISH packet with a QoS 0' do
      inject_packet(topic: 'topic0', payload: 'payload0', qos: 0)
      packet = client.get
      expect(packet.topic).to eq('topic0')
      expect(packet.payload).to eq('payload0')
    end

    it 'successfullies receive a valid PUBLISH packet with a QoS 1' do
      inject_packet(topic: 'topic1', payload: 'payload1', qos: 1)
      packet = client.get
      expect(packet.topic).to eq('topic1')
      expect(packet.payload).to eq('payload1')
      expect(client).to be_queue_empty
    end

    it 'acks calling #get and qos=1' do
      inject_packet(topic: 'topic1', payload: 'payload1', qos: 1)
      expect(client).to receive(:send_packet).with(an_instance_of(MQTT::Packet::Puback))
      client.get
    end

    context 'with a block' do
      it 'successfullies receive more than 1 message' do
        inject_packet(topic: 'topic0', payload: 'payload0')
        inject_packet(topic: 'topic1', payload: 'payload1')
        payloads = []
        client.get do |packet|
          payloads << packet.payload
          break if payloads.size > 1
        end
        expect(payloads.size).to eq(2)
        expect(payloads).to eq(%w[payload0 payload1])
      end

      it 'acks when qos > 1 after running the block' do
        inject_packet(topic: 'topic1', payload: 'payload1', qos: 1)
        inject_packet(topic: 'topic2', payload: 'payload1')
        expect(client).to receive(:send_packet).with(an_instance_of(MQTT::Packet::Puback))
        payloads = []
        client.get do |packet|
          payloads << packet.payload
          break if payloads.size > 1
        end
      end
    end
  end

  describe '#unsubscribe' do
    before do
      allow(client).to receive(:connected?).and_return(true)
      allow(client).to receive(:send_packet) do |packet|
        socket.write(packet.to_s)
      end
    end

    it 'writes a valid UNSUBSCRIBE packet to the socket if given a single topic String' do
      client.unsubscribe('a/b')
      expect(socket.string).to eq("\xa2\x07\x00\x01\x00\x03a/b")
    end

    it 'writes a valid UNSUBSCRIBE packet to the socket if given a two topic Strings' do
      client.unsubscribe('a/b', 'c/d')
      expect(socket.string).to eq("\xa2\x0c\x00\x01\x00\x03a/b\x00\x03c/d")
    end

    it 'writes a valid UNSUBSCRIBE packet to the socket if given an array of Strings' do
      client.unsubscribe(['a/b', 'c/d'])
      expect(socket.string).to eq("\xa2\x0c\x00\x01\x00\x03a/b\x00\x03c/d")
    end
  end

  describe '#receive_packet' do
    before do
      client.instance_variable_set(:@socket, socket)
      client.instance_variable_set(:@last_packet_received_at, 0)
      client.instance_variable_set :@last_packet_sent_at, client.send(:current_time)
      client.reconnect_limit = 0
      allow(IO).to receive(:select).and_return([[socket], [], []])
      @read_queue = client.instance_variable_get(:@read_queue)
    end

    it 'puts PUBLISH messages on to the read queue' do
      socket.write("\x30\x0e\x00\x05topicpayload")
      socket.rewind
      client.send(:receive_packet)
      expect(@read_queue.size).to eq(1)
    end

    it 'does not put other messages on to the read queue' do
      socket.write("\x20\x02\x00\x00")
      socket.rewind
      client.send(:receive_packet)
      expect(@read_queue.size).to eq(0)
    end

    it 'closes the socket if there is an exception' do
      expect(socket).to receive(:close).once
      client.instance_variable_set :@last_packet_sent_at, client.send(:current_time)
      allow(MQTT::Packet).to receive(:read).and_raise(MQTT::Exception.new)
      client.send(:receive_packet)
    end

    it 'passes exceptions up to parent thread' do
      client.reconnect_limit = 0
      allow(MQTT::Packet).to receive(:read).and_raise(MQTT::Exception)
      client.send(:receive_packet)
      expect { client.get }.to raise_error(MQTT::Exception)
    end

    it 'updates last_packet_received_at when receiving a Pingresp' do
      allow(MQTT::Packet).to receive(:read).and_return MQTT::Packet::Pingresp.new
      client.instance_variable_set :@last_packet_received_at, 0
      client.send :receive_packet
      expect(client.instance_variable_get(:@last_packet_received_at)).to be_within(1).of client.send(:current_time)
    end
  end

  describe '#handle_keep_alives' do
    before do
      client.instance_variable_set(:@socket, socket)
      allow(client).to receive(:send_packet) do |packet|
        socket.write(packet.to_s)
      end
    end

    it 'sends a ping packet if one is due' do
      client.instance_variable_set(:@last_packet_sent_at, 0)
      client.send(:handle_keep_alives)
      expect(socket.string).to eq("\xC0\x00")
      expect(client.instance_variable_get(:@keep_alive_sent)).to eq true
    end

    it 'raises an exception if no ping response has been received' do
      client.instance_variable_set(:@last_packet_received_at, 0)
      client.instance_variable_set(:@last_packet_sent_at, 0)
      client.instance_variable_set(:@keep_alive_sent, true)
      expect { client.send(:handle_keep_alives) }.to raise_error(MQTT::KeepAliveTimeout)
    end
  end

  describe 'generating a client identifier' do
    context 'with default parameters' do
      let(:client_id) { MQTT::Client.generate_client_id }

      it 'is less or equal to 23 characters long' do
        expect(client_id.length).to be <= 23
      end

      it 'has a prefix of ruby' do
        expect(client_id).to match(/^ruby/)
      end

      it 'ends in 16 characters of lowercase letters and numbers' do
        expect(client_id).to match(/^ruby[a-z0-9]{16}$/)
      end
    end

    context 'with an alternative prefix' do
      let(:client_id) { MQTT::Client.generate_client_id('test') }

      it 'is less or equal to 23 characters long' do
        expect(client_id.length).to be <= 23
      end

      it 'has a prefix of test' do
        expect(client_id).to match(/^test/)
      end

      it 'ends in 16 characters of lowercase letters and numbers' do
        expect(client_id).to match(/^test[a-z0-9]{16}$/)
      end
    end
  end

  private

  def inject_packet(opts = {})
    packet = MQTT::Packet::Publish.new(opts)
    client.instance_variable_get(:@read_queue).push(packet)
  end

  def inject_puback(packet_id)
    packet = MQTT::Packet::Puback.new(id: packet_id)
    client.inject_puback packet
  end
end
