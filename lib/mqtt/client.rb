autoload :OpenSSL, 'openssl'
autoload :SecureRandom, 'securerandom'
autoload :URI, 'uri'

# Client class for talking to an MQTT server
module MQTT
  class Client
    # Hostname of the remote server
    attr_accessor :host

    # Port number of the remote server
    attr_accessor :port

    # The version number of the MQTT protocol to use (default 3.1.1)
    attr_accessor :version

    # Set to true to enable SSL/TLS encrypted communication
    #
    # Set to a symbol to use a specific variant of SSL/TLS.
    # Allowed values include:
    #
    # @example Using TLS 1.0
    #    client = Client.new('mqtt.example.com', ssl: :TLSv1)
    # @see OpenSSL::SSL::SSLContext::METHODS
    attr_accessor :ssl

    # Time (in seconds) between pings to remote server (default is 15 seconds)
    attr_accessor :keep_alive

    # Set the 'Clean Session' flag when connecting? (default is true)
    attr_accessor :clean_session

    # Client Identifier
    attr_accessor :client_id

    # Number of seconds to wait for acknowledgement packets (default is 5 seconds)
    attr_accessor :ack_timeout

    # How many times to attempt re-sending packets that weren't acknowledged
    # (default is 5) before giving up
    attr_accessor :resend_limit

    # How many attempts to re-establish a connection after it drops before
    # giving up (default 5)
    attr_accessor :reconnect_limit

    # How long to wait between re-connection attempts (exponential - i.e.
    # immediately after first drop, then 5s, then 25s, then 125s, etc.
    # when theis value defaults to 5)
    attr_accessor :reconnect_backoff

    # Username to authenticate to the server with
    attr_accessor :username

    # Password to authenticate to the server with
    attr_accessor :password

    # The topic that the Will message is published to
    attr_accessor :will_topic

    # Contents of message that is sent by server when client disconnect
    attr_accessor :will_payload

    # The QoS level of the will message sent by the server
    attr_accessor :will_qos

    # If the Will message should be retain by the server after it is sent
    attr_accessor :will_retain

    # Default attribute values
    ATTR_DEFAULTS = {
      host: nil,
      port: nil,
      version: '3.1.1',
      keep_alive: 15,
      clean_session: true,
      client_id: nil,
      ack_timeout: 5,
      resend_limit: 5,
      reconnect_limit: 5,
      reconnect_backoff: 5,
      username: nil,
      password: nil,
      will_topic: nil,
      will_payload: nil,
      will_qos: 0,
      will_retain: false,
      ssl: false
    }

    # Create and connect a new MQTT Client
    #
    # Accepts the same arguments as creating a new client.
    # If a block is given, then it will be executed before disconnecting again.
    #
    # Example:
    #  MQTT::Client.connect('myserver.example.com') do |client|
    #    # do stuff here
    #  end
    #
    def self.connect(*args, &block)
      client = MQTT::Client.new(*args)
      client.connect(&block)
      client
    end

    # Generate a random client identifier
    # (using the characters 0-9 and a-z)
    def self.generate_client_id(prefix = 'ruby', length = 16)
      "#{prefix}#{SecureRandom.alphanumeric(length).downcase}"
    end

    # Create a new MQTT Client instance
    #
    # Accepts one of the following:
    # - a URI that uses the MQTT scheme
    # - a hostname and port
    # - a Hash containing attributes to be set on the new instance
    #
    # If no arguments are given then the method will look for a URI
    # in the MQTT_SERVER environment variable.
    #
    # Examples:
    #  client = MQTT::Client.new
    #  client = MQTT::Client.new('mqtt://myserver.example.com')
    #  client = MQTT::Client.new('mqtt://user:pass@myserver.example.com')
    #  client = MQTT::Client.new('myserver.example.com')
    #  client = MQTT::Client.new('myserver.example.com', 18830)
    #  client = MQTT::Client.new(host: 'myserver.example.com')
    #  client = MQTT::Client.new(host: 'myserver.example.com', keep_alive: 30)
    #
    def initialize(*args)
      attributes = args.last.is_a?(Hash) ? args.pop : {}

      # Set server URI from environment if present
      attributes.merge!(parse_uri(ENV['MQTT_SERVER'])) if args.length.zero? && ENV['MQTT_SERVER']

      if args.length >= 1
        case args[0]
        when URI
          attributes.merge!(parse_uri(args[0]))
        when %r{^mqtts?://}
          attributes.merge!(parse_uri(args[0]))
        else
          attributes[:host] = args[0]
        end
      end

      if args.length >= 2
        attributes[:port] = args[1] unless args[1].nil?
      end

      raise ArgumentError, 'Unsupported number of arguments' if args.length >= 3

      # Merge arguments with default values for attributes
      ATTR_DEFAULTS.merge(attributes).each_pair do |k, v|
        send("#{k}=", v)
      end

      # Set a default port number
      if @port.nil?
        @port = @ssl ? MQTT::DEFAULT_SSL_PORT : MQTT::DEFAULT_PORT
      end

      # Initialise private instance variables
      @socket = nil
      @read_queue = Queue.new
      @write_queue = Queue.new

      @read_thread = nil
      @write_thread = nil

      @acks = {}

      @connection_mutex = Mutex.new
      @acks_mutex = Mutex.new
      @wake_up_pipe = IO.pipe

      @connected = false
    end

    # Get the OpenSSL context, that is used if SSL/TLS is enabled
    def ssl_context
      @ssl_context ||= OpenSSL::SSL::SSLContext.new
    end

    # Set a path to a file containing a PEM-format client certificate
    def cert_file=(path)
      self.cert = File.read(path)
    end

    # PEM-format client certificate
    def cert=(cert)
      ssl_context.cert = OpenSSL::X509::Certificate.new(cert)
    end

    # Set a path to a file containing a PEM-format client private key
    def key_file=(*args)
      path, passphrase = args.flatten
      ssl_context.key = OpenSSL::PKey::RSA.new(File.open(path), passphrase)
    end

    # Set to a PEM-format client private key
    def key=(*args)
      cert, passphrase = args.flatten
      ssl_context.key = OpenSSL::PKey::RSA.new(cert, passphrase)
    end

    # Set a path to a file containing a PEM-format CA certificate and enable peer verification
    def ca_file=(path)
      ssl_context.ca_file = path
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER unless path.nil?
    end

    # Set the Will for the client
    #
    # The will is a message that will be delivered by the server when the client dies.
    # The Will must be set before establishing a connection to the server
    def set_will(topic, payload, retain: false, qos: 0)
      self.will_topic = topic
      self.will_payload = payload
      self.will_retain = retain
      self.will_qos = qos
    end

    # Connect to the MQTT server
    #
    # If a block is given, then yield to that block and then disconnect again.
    def connect
      if connected?
        yield(self) if block_given?
        return
      end

      if @client_id.nil? || @client_id.empty?
        raise 'Must provide a client_id if clean_session is set to false' unless @clean_session

        # Empty client id is not allowed for version 3.1.0
        @client_id = MQTT::Client.generate_client_id if @version == '3.1.0'
      end

      raise ArgumentError, 'No MQTT server host set when attempting to connect' if @host.nil?

      connect_internal

      return unless block_given?

      # If a block is given, then yield and disconnect
      begin
        yield(self)
      ensure
        disconnect
      end
    end

    # wait until all messages have been sent
    def flush
      raise NotConnectedException unless connected?

      queue = Queue.new
      @write_queue << queue
      queue.pop
      nil
    end

    # Disconnect from the MQTT server.
    #
    # If you don't want to say goodbye to the server, set send_msg to false.
    def disconnect(send_msg = true)
      return unless connected?

      @read_queue << [ConnectionClosedException.new, current_time]
      # Stop reading packets from the socket first
      @connection_mutex.synchronize do
        if @write_thread&.alive?
          @write_thread.kill
          @write_thread.join
        end
        @read_thread.kill if @read_thread&.alive?
        @read_thread = @write_thread = nil

        @connected = false
      end
      @acks_mutex.synchronize do
        @acks.each_value do |pending_ack|
          pending_ack.queue << :close
        end
        @acks.clear
      end

      return unless @socket

      if send_msg
        packet = MQTT::Packet::Disconnect.new
        @socket.write(packet.to_s) rescue nil
      end
      @socket.close
      @socket = nil
    end

    # Checks whether the client is connected to the server.
    #
    # Note that this returns true even if the connection is down and we're
    # trying to reconnect
    def connected?
      @connected
    end

    # registers a callback to be called when a connection is re-established
    #
    # can be used to re-subscribe (if you're not using persistent sessions)
    # to topics, and/or re-publish aliveness (if you set a Will)
    def on_reconnect(&block)
      @on_reconnect = block
    end

    # yields a block, and after the block returns all messages are
    # published at once, waiting for any necessary PubAcks for QoS 1
    # packets as a batch at the end
    #
    #  For example:
    #    client.batch_publish do
    #      client.publish("topic1", "value1", qos: 1)
    #      client.publish("topic2", "value2", qos: 1)
    #    end
    def batch_publish
      return yield if @batch_publish

      @batch_publish = {}

      begin
        yield

        batch = @batch_publish
        @batch_publish = nil
        batch.each do |(kwargs, values)|
          publish(values, **kwargs)
        end
      ensure
        @batch_publish = nil
      end
    end

    # Publish a message on a particular topic to the MQTT server.
    def publish(topics, payload = nil, retain: false, qos: 0)
      raise ArgumentError, 'Payload cannot be passed if passing a hash for topics and payloads' if topics.is_a?(Hash) && !payload.nil?
      raise NotConnectedException unless connected?

      if @batch_publish && qos != 0
        values = @batch_publish[{ retain: retain, qos: qos }] ||= {}
        if topics.is_a?(Hash)
          values.merge!(topics)
        else
          values[topics] = payload
        end
        return
      end

      pending_acks = []

      topics = { topics => payload } unless topics.is_a?(Hash)

      topics.each do |(topic, topic_payload)|
        raise ArgumentError, 'Topic name cannot be nil' if topic.nil?
        raise ArgumentError, 'Topic name cannot be empty' if topic.empty?

        packet = MQTT::Packet::Publish.new(
          id: next_packet_id,
          qos: qos,
          retain: retain,
          topic: topic,
          payload: topic_payload
        )

        pending_acks << register_for_ack(packet) unless qos.zero?

        # Send the packet
        send_packet(packet)
      end

      return if qos.zero?

      pending_acks.each do |ack|
        wait_for_ack(ack)
      end
      nil
    end

    # Send a subscribe message for one or more topics on the MQTT server.
    # The topics parameter should be one of the following:
    # * String: subscribe to one topic with QoS 0
    # * Array: subscribe to multiple topics with QoS 0
    # * Hash: subscribe to multiple topics where the key is the topic and the value is the QoS level
    #
    # For example:
    #   client.subscribe( 'a/b' )
    #   client.subscribe( 'a/b', 'c/d' )
    #   client.subscribe( ['a/b',0], ['c/d',1] )
    #   client.subscribe( 'a/b' => 0, 'c/d' => 1 )
    #
    def subscribe(*topics, wait_for_ack: false)
      raise NotConnectedException unless connected?

      packet = MQTT::Packet::Subscribe.new(
        id: next_packet_id,
        topics: topics
      )
      token = register_for_ack(packet) if wait_for_ack
      send_packet(packet)
      wait_for_ack(token) if wait_for_ack
    end

    # Send a unsubscribe message for one or more topics on the MQTT server
    def unsubscribe(*topics, wait_for_ack: false)
      raise NotConnectedException unless connected?

      topics = topics.first if topics.is_a?(Enumerable) && topics.count == 1

      packet = MQTT::Packet::Unsubscribe.new(
        topics: topics,
        id: next_packet_id
      )
      token = register_for_ack(packet) if wait_for_ack
      send_packet(packet)
      wait_for_ack(token) if wait_for_ack
    end

    # Return the next message received from the MQTT server.
    #
    # The method either returns the Publish packet:
    #   packet = client.get
    #
    # Or can be used with a block to keep processing messages:
    #   client.get do |packet|
    #     # Do stuff here
    #   end
    #
    def get
      raise NotConnectedException unless connected?
      
      loop_start = current_time
      loop do
        packet = @read_queue.pop
        if packet.is_a?(Array) && packet.last >= loop_start
          e = packet.first
          e.set_backtrace((e.backtrace || []) + ["<from MQTT worker thread>"] + caller)
          raise e
        end
        next unless packet.is_a?(Packet)

        unless block_given?
          puback_packet(packet) if packet.qos > 0
          return packet
        end

        yield packet
        puback_packet(packet) if packet.qos > 0
      end
    end

    # Returns true if the incoming message queue is empty.
    def queue_empty?
      @read_queue.empty?
    end

    # Returns the length of the incoming message queue.
    def queue_length
      @read_queue.length
    end

    # Clear the incoming message queue.
    def clear_queue
      @read_queue.clear
    end

    private

    PendingAck = Struct.new(:packet, :queue, :timeout_at, :send_count)

    def connect_internal
      # Create network socket
      tcp_socket = TCPSocket.new(@host, @port)

      if @ssl
        # Set the protocol version
        ssl_context.ssl_version = @ssl if @ssl.is_a?(Symbol)

        @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        @socket.sync_close = true

        # Set hostname on secure socket for Server Name Indication (SNI)
        @socket.hostname = @host if @socket.respond_to?(:hostname=)

        @socket.connect
      else
        @socket = tcp_socket
      end

      # Construct a connect packet
      packet = MQTT::Packet::Connect.new(
        version: @version,
        clean_session: @clean_session,
        keep_alive: @keep_alive,
        client_id: @client_id,
        username: @username,
        password: @password,
        will_topic: @will_topic,
        will_payload: @will_payload,
        will_qos: @will_qos,
        will_retain: @will_retain
      )

      # Send packet
      @socket.write(packet.to_s)

      # Receive response
      receive_connack

      @connected = true

      @write_thread = Thread.new do
        while (packet = @write_queue.pop)
          # flush command
          if packet.is_a?(Queue)
            packet << :flushed
            next
          end
          @socket.write(packet.to_s)
        end
      rescue => e
        @write_queue << packet if packet
        reconnect(e)
      end

      @read_thread = Thread.new do
        receive_packet while connected?
      end
    end

    def reconnect(exception)
      should_exit = nil
      @connection_mutex.synchronize do
        @socket&.close
        @socket = nil
        @read_thread&.kill if Thread.current != @read_thread
        @write_thread&.kill if Thread.current != @write_thread
        should_exit = Thread.current == @read_thread
        @read_thread = @write_thread = nil

        retries = 0
        begin
          connect_internal unless @reconnect_limit == 0
        rescue
          @socket&.close
          @socket = nil

          if (retries += 1) < @reconnect_limit
            sleep @reconnect_backoff ** retries
            retry
          end
        end

        unless @socket
          # couldn't reconnect
          @acks_mutex.synchronize do
            @acks.each_value do |pending_ack|
              pending_ack.queue << :close
            end
            @acks.clear
          end
          @connected = false
          @read_queue << [exception, current_time]
          return
        end
      end

      begin
        @on_reconnect&.call
      rescue => e
        @read_queue << [e, current_time]
        disconnect
      end
      Thread.exit if should_exit
    end

    # Try to read a packet from the server
    # Also sends keep-alive ping packets.
    def receive_packet
      # Poll socket - is there data waiting?
      timeout = next_timeout
      read_ready, _ = IO.select([@socket, @wake_up_pipe[0]], [], [], timeout)

      # we just needed to break out of our select to set up a new timeout;
      # we can discard the actual contents
      if read_ready&.include?(@wake_up_pipe[0])
        @wake_up_pipe[0].readpartial(4096)
      end

      handle_timeouts

      if read_ready&.include?(@socket)
        packet = MQTT::Packet.read(@socket)
        handle_packet(packet)
      end

      handle_keep_alives
    rescue => e
      reconnect(e)
    end

    def register_for_ack(packet)
      queue = Queue.new

      timeout_at = current_time + @ack_timeout
      @acks_mutex.synchronize do
        if @acks.empty?
          # just need to wake up the read thread to set up the timeout for this packet
          @wake_up_pipe[1].write('z')
        end
        @acks[packet.id] = PendingAck.new(packet, queue, timeout_at, 1)
      end
    end

    def wait_for_ack(pending_ack)
      response = pending_ack.queue.pop
      case response
      when :close
        raise ConnectionClosedException
      when :resend_limit_exceeded
        raise ResendLimitExceededException
      end
    end

    def handle_packet(packet)
      @last_packet_received_at = current_time
      @keep_alive_sent = false
      case packet
      when MQTT::Packet::Publish
        # Add to queue
        @read_queue.push(packet)
      when MQTT::Packet::Pingresp
        # do nothing; setting @last_packet_received_at already handled it
      when MQTT::Packet::Puback,
        MQTT::Packet::Suback,
        MQTT::Packet::Unsuback
        @acks_mutex.synchronize do
          pending_ack = @acks[packet.id]
          if pending_ack
            @acks.delete(packet.id)
            pending_ack.queue << packet
          end
        end
      end
      # Ignore all other packets
      # FIXME: implement responses for QoS  2
    end

    def handle_timeouts
      @acks_mutex.synchronize do
        current_time = self.current_time
        @acks.each_value do |pending_ack|
          if pending_ack.timeout_at <= current_time
            resend(pending_ack)
          else
            break
          end
        end
      end
    end

    def resend(pending_ack)
      packet = pending_ack.packet
      if (pending_ack.send_count += 1) > @resend_limit
        @acks.delete(packet.id)
        pending_ack.queue << :resend_limit_exceeded
        return
      end
      # timed out, or simple re-send
      if @acks.first.first == packet.id
        @wake_up_pipe[1].write('z')
      end
      pending_ack.timeout_at = current_time + @ack_timeout
      # TODO: set re-send flag
      send_packet(packet)
    end

    def current_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def next_timeout
      timeout_from_acks = @acks_mutex.synchronize do
        @acks.first&.last&.timeout_at
      end
      return nil if timeout_from_acks.nil? && @keep_alive.nil?

      next_ping = @last_packet_received_at + @keep_alive if @keep_alive && !@keep_alive_sent
      next_ping = @last_packet_received_at + @keep_alive + @ack_timeout if @keep_alive && @keep_alive_sent
      current_time = self.current_time
      [([timeout_from_acks, next_ping].compact.min || current_time) - current_time, 0].max
    end

    def handle_keep_alives
      return unless @keep_alive && @keep_alive > 0

      current_time = self.current_time
      if current_time >= @last_packet_received_at + @keep_alive && !@keep_alive_sent
        packet = MQTT::Packet::Pingreq.new
        send_packet(packet)
        @keep_alive_sent = true
      elsif current_time >= @last_packet_received_at + @keep_alive + @ack_timeout
        raise KeepAliveTimeout
      end
    end

    def puback_packet(packet)
      send_packet(MQTT::Packet::Puback.new(id: packet.id))
    end

    # Read and check a connection acknowledgement packet
    def receive_connack
      Timeout.timeout(@ack_timeout) do
        packet = MQTT::Packet.read(@socket)
        if packet.class != MQTT::Packet::Connack
          raise MQTT::ProtocolException, "Response wasn't a connection acknowledgement: #{packet.class}"
        end

        # Check the return code
        if packet.return_code != 0x00
          # 3.2.2.3 If a server sends a CONNACK packet containing a non-zero
          # return code it MUST then close the Network Connection
          @socket.close
          raise MQTT::ProtocolException, packet.return_msg
        end
        @last_packet_received_at = current_time
        @keep_alive_sent = false
      end
    end

    # Send a packet to server
    def send_packet(packet)
      @write_queue << packet
    end

    def parse_uri(uri)
      uri = URI.parse(uri) unless uri.is_a?(URI)
      if uri.scheme == 'mqtt'
        ssl = false
      elsif uri.scheme == 'mqtts'
        ssl = true
      else
        raise 'Only the mqtt:// and mqtts:// schemes are supported'
      end

      {
        host: uri.host,
        port: uri.port || nil,
        username: uri.user ? URI::Parser.new.unescape(uri.user) : nil,
        password: uri.password ? URI::Parser.new.unescape(uri.password) : nil,
        ssl: ssl
      }
    end

    def next_packet_id
      @last_packet_id = (@last_packet_id || 0).next
      @last_packet_id = 1 if @last_packet_id > 0xffff
      @last_packet_id
    end
  end
end
