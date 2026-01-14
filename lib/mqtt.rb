# frozen_string_literal: true

require "logger"
require "socket"
require "timeout"

require "mqtt/version"

module MQTT
  # Default port number for unencrypted connections
  DEFAULT_PORT = 1883

  # Default port number for TLS/SSL encrypted connections
  DEFAULT_SSL_PORT = 8883

  # Super-class for other MQTT related exceptions
  class Exception < RuntimeError
  end

  # A ProtocolException will be raised if there is a
  # problem with data received from a remote host
  class ProtocolException < Exception
  end

  class KeepAliveTimeout < ProtocolException
  end

  # A NotConnectedException will be raised when trying to
  # perform a function but no connection has been
  # established
  class NotConnectedException < Exception
  end

  # A ConnectionClosedException will be raised when the
  # connection has been closed while waiting for an operation
  # to complete
  class ConnectionClosedException < Exception
  end

  # A ResendLimitExceededException will be raised when a packet
  # has timed out without an ack too many times
  class ResendLimitExceededException < Exception
  end

  autoload :Client,   "mqtt/client"
  autoload :Packet,   "mqtt/packet"
  autoload :Proxy,    "mqtt/proxy"

  # MQTT-SN
  module SN
    # Default port number for unencrypted connections
    DEFAULT_PORT = 1883

    # A ProtocolException will be raised if there is a
    # problem with data received from a remote host
    class ProtocolException < MQTT::Exception
    end

    autoload :Packet, "mqtt/sn/packet"
  end
end
